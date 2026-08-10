//! 只负责传输层，路由与业务全在 Dart 侧的 handler 回调里。
//! 大 body 流式落盘（移动端不吃内存）；响应支持单段 Range —— webview `<video>` 依赖 206。

use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering};

use anyhow::{Context, Result};
use bytes::Bytes;
use futures::TryStreamExt;
use futures::future::BoxFuture;
use http_body_util::{BodyExt, Full, StreamBody};
use hyper::body::{Frame, Incoming};
use hyper::service::service_fn;
use tokio::io::{AsyncReadExt, AsyncSeekExt, AsyncWriteExt};
use tokio::net::TcpListener;
use tokio::sync::oneshot;

use crate::request::KeyValue;

pub struct HttpServerRequest {
    pub method: String,
    pub path: String,
    pub query: Vec<KeyValue>,
    pub headers: Vec<KeyValue>,
    /// 小请求体内联；已落盘时为空、见 [Self::body_file_path]。
    pub body: Vec<u8>,
    /// 大请求体流式落盘的临时文件。仅在 handler 执行期间有效，返回后由服务器删除。
    pub body_file_path: Option<String>,
}

/// handler 返回的响应。[Self::body_file_path] 非空时从磁盘流式发送并自动支持
/// Range（此时 [Self::body] 被忽略）。
pub struct HttpServerResponse {
    pub status: u16,
    pub headers: Vec<KeyValue>,
    pub body: Vec<u8>,
    pub body_file_path: Option<String>,
}

const SPOOL_THRESHOLD: usize = 256 * 1024;
const PROGRESS_STEP: i64 = 512 * 1024;

static SPOOL_SEQ: AtomicU64 = AtomicU64::new(0);

type BoxedBody = http_body_util::combinators::BoxBody<Bytes, std::io::Error>;
pub type HandlerFn =
    Arc<dyn Fn(HttpServerRequest) -> BoxFuture<'static, HttpServerResponse> + Send + Sync>;
/// (received, total)，total 为 -1 表示长度未知（chunked）。
pub type ProgressFn = Arc<dyn Fn(i64, i64) -> BoxFuture<'static, ()> + Send + Sync>;

pub struct HttpServer {
    port: u16,
    shutdown: Option<oneshot::Sender<()>>,
}

impl HttpServer {
    pub async fn start(
        preferred_port: u16,
        loopback_only: bool,
        spool_dir: String,
        handler: HandlerFn,
        progress: ProgressFn,
    ) -> Result<HttpServer> {
        let ip = if loopback_only {
            IpAddr::V4(Ipv4Addr::LOCALHOST)
        } else {
            IpAddr::V4(Ipv4Addr::UNSPECIFIED)
        };
        let listener = match TcpListener::bind(SocketAddr::new(ip, preferred_port)).await {
            Ok(l) => l,
            Err(_) if preferred_port != 0 => TcpListener::bind(SocketAddr::new(ip, 0))
                .await
                .context("bind fallback port failed")?,
            Err(e) => return Err(e).context("bind failed"),
        };
        let port = listener
            .local_addr()
            .context("read local addr failed")?
            .port();
        let (tx, mut rx) = oneshot::channel::<()>();
        let spool_dir = Arc::new(PathBuf::from(spool_dir));

        tokio::spawn(async move {
            let mut connections = tokio::task::JoinSet::new();
            loop {
                tokio::select! {
                    _ = &mut rx => break,
                    accepted = listener.accept() => {
                        let Ok((stream, _)) = accepted else { continue };
                        let handler = handler.clone();
                        let progress = progress.clone();
                        let spool_dir = spool_dir.clone();
                        connections.spawn(async move {
                            let io = hyper_util::rt::TokioIo::new(stream);
                            let service = service_fn(move |req| {
                                serve_one(req, handler.clone(), progress.clone(), spool_dir.clone())
                            });
                            let _ = hyper::server::conn::http1::Builder::new()
                                .serve_connection(io, service)
                                .await;
                        });
                    }
                }
            }
            // stop() 语义 = close(force)：在飞连接直接掐断。
            connections.abort_all();
        });

        Ok(HttpServer {
            port,
            shutdown: Some(tx),
        })
    }

    pub fn port(&self) -> u16 {
        self.port
    }

    pub fn stop(&mut self) {
        if let Some(tx) = self.shutdown.take() {
            let _ = tx.send(());
        }
    }
}

/// 单个请求的完整生命周期。任何内部错误统一映射为 500，绝不让连接层报错。
async fn serve_one(
    req: hyper::Request<Incoming>,
    handler: HandlerFn,
    progress: ProgressFn,
    spool_dir: Arc<PathBuf>,
) -> Result<hyper::Response<BoxedBody>, std::convert::Infallible> {
    let response = match serve_inner(req, handler, progress, &spool_dir).await {
        Ok(resp) => resp,
        Err(e) => text_response(500, &e.to_string()),
    };
    Ok(response)
}

async fn serve_inner(
    req: hyper::Request<Incoming>,
    handler: HandlerFn,
    progress: ProgressFn,
    spool_dir: &Path,
) -> Result<hyper::Response<BoxedBody>> {
    let (parts, body) = req.into_parts();

    let query = parts
        .uri
        .query()
        .map(|q| {
            url::form_urlencoded::parse(q.as_bytes())
                .map(|(k, v)| KeyValue {
                    key: k.into_owned(),
                    value: v.into_owned(),
                })
                .collect()
        })
        .unwrap_or_default();
    let headers: Vec<KeyValue> = parts
        .headers
        .iter()
        .map(|(k, v)| KeyValue {
            key: k.as_str().to_lowercase(),
            value: v.to_str().unwrap_or_default().to_string(),
        })
        .collect();
    let range_header = parts
        .headers
        .get(hyper::header::RANGE)
        .and_then(|v| v.to_str().ok())
        .map(str::to_string);
    let total: i64 = parts
        .headers
        .get(hyper::header::CONTENT_LENGTH)
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.parse().ok())
        .unwrap_or(-1);

    let collected = collect_body(body, spool_dir, &progress, total).await?;

    let request = HttpServerRequest {
        method: parts.method.as_str().to_uppercase(),
        path: parts.uri.path().to_string(),
        query,
        headers,
        body: collected.inline,
        body_file_path: collected
            .file_path
            .as_ref()
            .map(|p| p.to_string_lossy().into_owned()),
    };

    let response = handler(request).await;

    // 落盘的请求体只在 handler 执行期间有效。
    if let Some(path) = collected.file_path {
        let _ = tokio::fs::remove_file(path).await;
    }

    match response.body_file_path {
        Some(path) => file_response(&path, response.status, response.headers, range_header).await,
        None => Ok(bytes_response(
            response.status,
            response.headers,
            response.body,
        )),
    }
}

struct CollectedBody {
    inline: Vec<u8>,
    file_path: Option<PathBuf>,
}

async fn collect_body(
    mut body: Incoming,
    spool_dir: &Path,
    progress: &ProgressFn,
    total: i64,
) -> Result<CollectedBody> {
    let mut inline = Vec::new();
    let mut file: Option<(tokio::fs::File, PathBuf)> = None;
    let mut received: i64 = 0;
    let mut last_report: i64 = 0;

    while let Some(frame) = body.frame().await {
        let frame = frame.context("read request body failed")?;
        let Ok(data) = frame.into_data() else {
            continue; // trailers
        };
        received += data.len() as i64;
        if file.is_none() && inline.len() + data.len() > SPOOL_THRESHOLD {
            let path = spool_dir.join(format!(
                "http-body-{}-{}.tmp",
                std::process::id(),
                SPOOL_SEQ.fetch_add(1, Ordering::Relaxed),
            ));
            let mut f = tokio::fs::File::create(&path)
                .await
                .with_context(|| format!("create spool file failed: {}", path.display()))?;
            f.write_all(&inline).await.context("spool write failed")?;
            inline.clear();
            file = Some((f, path));
        }
        match &mut file {
            Some((f, _)) => f.write_all(&data).await.context("spool write failed")?,
            None => inline.extend_from_slice(&data),
        }
        if received - last_report >= PROGRESS_STEP {
            last_report = received;
            progress(received, total).await;
        }
    }
    if let Some((f, _)) = &mut file {
        f.flush().await.context("spool flush failed")?;
    }
    if received > 0 && received != last_report {
        progress(received, total).await;
    }

    Ok(CollectedBody {
        inline,
        file_path: file.map(|(_, path)| path),
    })
}

fn bytes_response(
    status: u16,
    headers: Vec<KeyValue>,
    body: Vec<u8>,
) -> hyper::Response<BoxedBody> {
    let mut builder = hyper::Response::builder().status(status);
    for kv in headers {
        builder = builder.header(kv.key, kv.value);
    }
    builder
        .body(Full::new(Bytes::from(body)).map_err(|e| match e {}).boxed())
        .unwrap_or_else(|e| text_response(500, &format!("build response failed: {e}")))
}

fn text_response(status: u16, message: &str) -> hyper::Response<BoxedBody> {
    hyper::Response::builder()
        .status(status)
        .header(hyper::header::CONTENT_TYPE, "text/plain; charset=utf-8")
        .body(
            Full::new(Bytes::from(message.as_bytes().to_vec()))
                .map_err(|e| match e {})
                .boxed(),
        )
        .expect("static response")
}

/// 从磁盘流式供给文件，自动支持单段 HTTP Range：
/// - 无 Range → 200 全量（带 `Accept-Ranges: bytes`）；
/// - 合法 Range → 206 + `Content-Range` + 精确 `Content-Length`，只读对应区间；
/// - 不可满足的 Range → 416 + `Content-Range: bytes */total`。
async fn file_response(
    path: &str,
    status: u16,
    headers: Vec<KeyValue>,
    range_header: Option<String>,
) -> Result<hyper::Response<BoxedBody>> {
    let Ok(mut file) = tokio::fs::File::open(path).await else {
        return Ok(text_response(404, "file not found"));
    };
    let total = file.metadata().await.context("stat file failed")?.len();

    let range = match &range_header {
        Some(header) => match parse_range(header, total) {
            Some(range) => Some(range),
            None => {
                return Ok(hyper::Response::builder()
                    .status(416)
                    .header(hyper::header::CONTENT_RANGE, format!("bytes */{total}"))
                    .body(Full::new(Bytes::new()).map_err(|e| match e {}).boxed())
                    .expect("static response"));
            }
        },
        None => None,
    };

    let (start, end) = range.unwrap_or((0, total.saturating_sub(1)));
    let len = if total == 0 { 0 } else { end - start + 1 };
    if start > 0 {
        file.seek(std::io::SeekFrom::Start(start))
            .await
            .context("seek failed")?;
    }
    let stream = tokio_util::io::ReaderStream::new(file.take(len)).map_ok(Frame::data);

    let mut builder = hyper::Response::builder()
        .status(if range.is_some() { 206 } else { status })
        .header(hyper::header::ACCEPT_RANGES, "bytes")
        .header(hyper::header::CONTENT_LENGTH, len);
    if range.is_some() {
        builder = builder.header(
            hyper::header::CONTENT_RANGE,
            format!("bytes {start}-{end}/{total}"),
        );
    }
    for kv in headers {
        builder = builder.header(kv.key, kv.value);
    }
    Ok(builder
        .body(StreamBody::new(stream).boxed())
        .unwrap_or_else(|e| text_response(500, &format!("build response failed: {e}"))))
}

/// 解析单段 Range（`bytes=start-end` / `bytes=start-` / `bytes=-suffix`）为闭区间。
/// 多段 / 语法错误 / 起点越界返回 None（调用方回 416）。
fn parse_range(header: &str, total: u64) -> Option<(u64, u64)> {
    if total == 0 {
        return None;
    }
    let spec = header.strip_prefix("bytes=")?.trim();
    if spec.is_empty() || spec.contains(',') {
        return None;
    }
    let dash = spec.find('-')?;
    let (start_str, end_str) = (spec[..dash].trim(), spec[dash + 1..].trim());
    let (start, mut end) = if start_str.is_empty() {
        // `-suffix`：末尾 N 字节。
        let suffix: u64 = end_str.parse().ok().filter(|n| *n > 0)?;
        (total.saturating_sub(suffix), total - 1)
    } else {
        let start: u64 = start_str.parse().ok()?;
        let end: u64 = if end_str.is_empty() {
            total - 1
        } else {
            end_str.parse().ok()?
        };
        (start, end)
    };
    if start >= total {
        return None;
    }
    if end >= total {
        end = total - 1;
    }
    if start > end {
        return None;
    }
    Some((start, end))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    fn test_handler(
        f: impl Fn(HttpServerRequest) -> HttpServerResponse + Send + Sync + 'static,
    ) -> HandlerFn {
        let f = Arc::new(f);
        Arc::new(move |req| {
            let f = f.clone();
            Box::pin(async move { f(req) })
        })
    }

    fn noop_progress() -> ProgressFn {
        Arc::new(|_, _| Box::pin(async {}))
    }

    fn test_dir(tag: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!(
            "moodiary-http-server-test-{tag}-{}",
            std::process::id()
        ));
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[tokio::test]
    async fn roundtrip_small_body_and_query() {
        let dir = test_dir("small");
        let handler = test_handler(|req| {
            assert_eq!(req.method, "POST");
            assert_eq!(req.path, "/echo");
            assert_eq!(req.query.len(), 1);
            assert_eq!(req.query[0].key, "a");
            assert_eq!(req.query[0].value, "b c");
            assert!(req.body_file_path.is_none());
            HttpServerResponse {
                status: 200,
                headers: vec![KeyValue {
                    key: "x-test".into(),
                    value: "1".into(),
                }],
                body: req.body,
                body_file_path: None,
            }
        });
        let mut server = HttpServer::start(
            0,
            true,
            dir.to_string_lossy().into_owned(),
            handler,
            noop_progress(),
        )
        .await
        .unwrap();

        let client = reqwest::Client::new();
        let resp = client
            .post(format!("http://127.0.0.1:{}/echo?a=b%20c", server.port()))
            .body("hello")
            .send()
            .await
            .unwrap();
        assert_eq!(resp.status().as_u16(), 200);
        assert_eq!(resp.headers()["x-test"], "1");
        assert_eq!(resp.bytes().await.unwrap().as_ref(), b"hello");

        server.stop();
        std::fs::remove_dir_all(&dir).ok();
    }

    #[tokio::test]
    async fn large_body_spools_to_file_with_progress() {
        let dir = test_dir("spool");
        let seen = Arc::new(Mutex::new((Vec::new(), 0usize)));
        let seen_in_handler = seen.clone();
        let handler = test_handler(move |req| {
            assert!(req.body.is_empty());
            let path = req.body_file_path.expect("should spool");
            let bytes = std::fs::read(&path).unwrap();
            seen_in_handler.lock().unwrap().1 = bytes.len();
            HttpServerResponse {
                status: 200,
                headers: vec![],
                body: b"ok".to_vec(),
                body_file_path: None,
            }
        });
        let progress_seen = seen.clone();
        let progress: ProgressFn = Arc::new(move |received, total| {
            progress_seen.lock().unwrap().0.push((received, total));
            Box::pin(async {})
        });
        let mut server = HttpServer::start(
            0,
            true,
            dir.to_string_lossy().into_owned(),
            handler,
            progress,
        )
        .await
        .unwrap();

        let payload = vec![7u8; 2 * 1024 * 1024];
        let client = reqwest::Client::new();
        let resp = client
            .post(format!("http://127.0.0.1:{}/upload", server.port()))
            .body(payload.clone())
            .send()
            .await
            .unwrap();
        assert_eq!(resp.status().as_u16(), 200);

        let (progress_events, handler_len) = {
            let guard = seen.lock().unwrap();
            (guard.0.clone(), guard.1)
        };
        assert_eq!(handler_len, payload.len());
        assert!(!progress_events.is_empty());
        assert_eq!(progress_events.last().unwrap().0, payload.len() as i64);
        assert_eq!(progress_events.last().unwrap().1, payload.len() as i64);
        // handler 返回后落盘文件已清理
        assert_eq!(std::fs::read_dir(&dir).unwrap().count(), 0);

        server.stop();
        std::fs::remove_dir_all(&dir).ok();
    }

    #[tokio::test]
    async fn file_response_supports_range() {
        let dir = test_dir("range");
        let media = dir.join("media.bin");
        std::fs::write(&media, (0u8..=99).collect::<Vec<u8>>()).unwrap();

        let media_path = media.to_string_lossy().into_owned();
        let handler = test_handler(move |_| HttpServerResponse {
            status: 200,
            headers: vec![KeyValue {
                key: "content-type".into(),
                value: "application/octet-stream".into(),
            }],
            body: vec![],
            body_file_path: Some(media_path.clone()),
        });
        let mut server = HttpServer::start(
            0,
            true,
            dir.to_string_lossy().into_owned(),
            handler,
            noop_progress(),
        )
        .await
        .unwrap();
        let base = format!("http://127.0.0.1:{}/f", server.port());
        let client = reqwest::Client::new();

        let full = client.get(&base).send().await.unwrap();
        assert_eq!(full.status().as_u16(), 200);
        assert_eq!(full.headers()["accept-ranges"], "bytes");
        assert_eq!(full.bytes().await.unwrap().len(), 100);

        let partial = client
            .get(&base)
            .header("range", "bytes=10-19")
            .send()
            .await
            .unwrap();
        assert_eq!(partial.status().as_u16(), 206);
        assert_eq!(partial.headers()["content-range"], "bytes 10-19/100");
        let bytes = partial.bytes().await.unwrap();
        assert_eq!(bytes.as_ref(), &(10u8..=19).collect::<Vec<u8>>()[..]);

        let suffix = client
            .get(&base)
            .header("range", "bytes=-5")
            .send()
            .await
            .unwrap();
        assert_eq!(suffix.status().as_u16(), 206);
        assert_eq!(
            suffix.bytes().await.unwrap().as_ref(),
            &[95, 96, 97, 98, 99]
        );

        let bad = client
            .get(&base)
            .header("range", "bytes=200-")
            .send()
            .await
            .unwrap();
        assert_eq!(bad.status().as_u16(), 416);
        assert_eq!(bad.headers()["content-range"], "bytes */100");

        server.stop();
        std::fs::remove_dir_all(&dir).ok();
    }

    #[tokio::test]
    async fn upload_file_streams_to_server_with_content_length() {
        use crate::request::{ClientSettings, HttpClient, HttpMethod};

        let dir = test_dir("upload");
        let payload = vec![3u8; 3 * 1024 * 1024];
        std::fs::write(dir.join("src.bin"), &payload).unwrap();

        let totals = Arc::new(Mutex::new(Vec::<i64>::new()));
        let totals_in_progress = totals.clone();
        let progress: ProgressFn = Arc::new(move |_, total| {
            totals_in_progress.lock().unwrap().push(total);
            Box::pin(async {})
        });
        let handler = test_handler(|req| {
            let path = req.body_file_path.expect("should spool");
            let len = std::fs::metadata(path).unwrap().len();
            HttpServerResponse {
                status: 200,
                headers: vec![],
                body: len.to_string().into_bytes(),
                body_file_path: None,
            }
        });
        let mut server = HttpServer::start(
            0,
            true,
            dir.to_string_lossy().into_owned(),
            handler,
            progress,
        )
        .await
        .unwrap();

        let client = HttpClient::new(ClientSettings {
            base_url: None,
            connect_timeout_ms: Some(3000),
            timeout_ms: None,
            user_agent: None,
            max_redirects: None,
            throw_on_status: true,
        })
        .unwrap();
        let sent = Arc::new(Mutex::new(Vec::<(i64, i64)>::new()));
        let sent_in_progress = sent.clone();
        let (response, total) = client
            .upload_file(
                crate::request::RequestOptions {
                    method: HttpMethod::Post,
                    url: format!("http://127.0.0.1:{}/upload", server.port()),
                    query: vec![],
                    headers: vec![],
                    timeout_ms: None,
                    throw_on_status: None,
                },
                dir.join("src.bin").to_string_lossy().into_owned(),
                move |s, t| sent_in_progress.lock().unwrap().push((s, t)),
                || false,
            )
            .await
            .unwrap();

        assert_eq!(total, payload.len() as i64);
        assert_eq!(response.status, 200);
        // 服务端收到完整字节数（handler 回显 spool 文件长度）
        assert_eq!(response.body, payload.len().to_string().into_bytes());
        // content-length 生效：服务端进度事件的 total 已知而非 -1
        assert!(
            totals
                .lock()
                .unwrap()
                .iter()
                .all(|t| *t == payload.len() as i64)
        );
        // 客户端进度单调且收尾于总长
        let sent = sent.lock().unwrap();
        assert_eq!(sent.last().unwrap().0, payload.len() as i64);

        server.stop();
        std::fs::remove_dir_all(&dir).ok();
    }
}
