//! 「字节进、字节出」的透明转发：json / form / text 编码与响应解码都在 Dart 侧做。

use std::time::Duration;

use futures::StreamExt;

use crate::KeyValue;
use crate::client::builder as http_client_builder;

#[derive(Clone, Copy)]
pub enum HttpMethod {
    Get,
    Post,
    Put,
    Delete,
    Patch,
    Head,
    Options,
}

impl From<HttpMethod> for reqwest::Method {
    fn from(m: HttpMethod) -> Self {
        match m {
            HttpMethod::Get => reqwest::Method::GET,
            HttpMethod::Post => reqwest::Method::POST,
            HttpMethod::Put => reqwest::Method::PUT,
            HttpMethod::Delete => reqwest::Method::DELETE,
            HttpMethod::Patch => reqwest::Method::PATCH,
            HttpMethod::Head => reqwest::Method::HEAD,
            HttpMethod::Options => reqwest::Method::OPTIONS,
        }
    }
}

pub struct ClientSettings {
    /// 相对 url 的基准；为 None 时所有请求都必须传绝对 url。
    pub base_url: Option<String>,
    pub connect_timeout_ms: Option<u32>,
    pub timeout_ms: Option<u32>,
    pub user_agent: Option<String>,
    /// None=reqwest 默认(最多 10 跳)，Some(0)=不跟随重定向，Some(n)=最多 n 跳。
    pub max_redirects: Option<u32>,
    /// 为 true 时非 2xx 响应抛 [HttpErrorKind::Status]（对齐旧 Dio 行为）。
    pub throw_on_status: bool,
}

pub struct RequestOptions {
    pub method: HttpMethod,
    pub url: String,
    pub query: Vec<KeyValue>,
    pub headers: Vec<KeyValue>,
    pub timeout_ms: Option<u32>,
    /// 覆盖 client 级 throw_on_status；None 沿用。
    pub throw_on_status: Option<bool>,
}

#[derive(Clone)]
pub struct HttpResponse {
    pub status: u16,
    pub headers: Vec<KeyValue>,
    pub body: Vec<u8>,
}

#[derive(Debug)]
pub enum HttpErrorKind {
    Timeout,
    Connect,
    Request,
    Redirect,
    Decode,
    Status,
    Unknown,
}

#[derive(Debug)]
pub struct HttpError {
    pub kind: HttpErrorKind,
    pub status: Option<u16>,
    pub message: String,
}

fn map_reqwest_err(e: reqwest::Error) -> HttpError {
    let kind = if e.is_timeout() {
        HttpErrorKind::Timeout
    } else if e.is_connect() {
        HttpErrorKind::Connect
    } else if e.is_redirect() {
        HttpErrorKind::Redirect
    } else if e.is_decode() || e.is_body() {
        HttpErrorKind::Decode
    } else if e.is_request() || e.is_builder() {
        HttpErrorKind::Request
    } else {
        HttpErrorKind::Unknown
    };
    HttpError {
        kind,
        status: e.status().map(|s| s.as_u16()),
        message: e.to_string(),
    }
}

fn err(kind: HttpErrorKind, message: impl Into<String>) -> HttpError {
    HttpError {
        kind,
        status: None,
        message: message.into(),
    }
}

pub struct HttpClient {
    inner: reqwest::Client,
    base_url: Option<String>,
    throw_on_status: bool,
}

impl HttpClient {
    pub fn new(settings: ClientSettings) -> Result<HttpClient, HttpError> {
        // 这里不复用 http_client::shared()：user_agent / max_redirects 在 reqwest 里是
        // client 级设置，做不到 per-request，所以按 settings 单独建一个。TLS 配置同源。
        let mut builder =
            http_client_builder().map_err(|e| err(HttpErrorKind::Unknown, e.to_string()))?;
        if let Some(ms) = settings.connect_timeout_ms {
            builder = builder.connect_timeout(Duration::from_millis(ms as u64));
        }
        if let Some(ms) = settings.timeout_ms {
            builder = builder.timeout(Duration::from_millis(ms as u64));
        }
        if let Some(ua) = settings.user_agent.as_deref() {
            builder = builder.user_agent(ua);
        }
        builder = match settings.max_redirects {
            Some(0) => builder.redirect(reqwest::redirect::Policy::none()),
            Some(n) => builder.redirect(reqwest::redirect::Policy::limited(n as usize)),
            None => builder,
        };
        let inner = builder.build().map_err(map_reqwest_err)?;
        Ok(HttpClient {
            inner,
            base_url: settings.base_url,
            throw_on_status: settings.throw_on_status,
        })
    }

    /// 相对 url 用 base_url 解析；base_url 为 None 时要求绝对 url。传入的绝对 url 即便
    /// 有 base_url 也按其自身解析（Url::join 语义）。
    fn resolve_url(&self, url: &str) -> Result<reqwest::Url, HttpError> {
        match self.base_url.as_deref() {
            Some(base) => reqwest::Url::parse(base)
                .and_then(|b| b.join(url))
                .map_err(|e| err(HttpErrorKind::Request, format!("invalid url: {e}"))),
            None => reqwest::Url::parse(url)
                .map_err(|e| err(HttpErrorKind::Request, format!("invalid url: {e}"))),
        }
    }

    fn builder(&self, options: &RequestOptions) -> Result<reqwest::RequestBuilder, HttpError> {
        let mut full_url = self.resolve_url(&options.url)?;
        if !options.query.is_empty() {
            // reqwest 关了默认特性，RequestBuilder::query 不可用；直接往 Url 追加
            // query（application/x-www-form-urlencoded，语义一致）。
            let mut pairs = full_url.query_pairs_mut();
            for kv in &options.query {
                pairs.append_pair(&kv.key, &kv.value);
            }
        }
        let mut req = self.inner.request(options.method.into(), full_url);
        for h in &options.headers {
            req = req.header(&h.key, &h.value);
        }
        if let Some(ms) = options.timeout_ms {
            req = req.timeout(Duration::from_millis(ms as u64));
        }
        Ok(req)
    }

    pub async fn request(
        &self,
        options: RequestOptions,
        body: Option<Vec<u8>>,
    ) -> Result<HttpResponse, HttpError> {
        let mut req = self.builder(&options)?;
        if let Some(b) = body {
            req = req.body(b);
        }
        let resp = req.send().await.map_err(map_reqwest_err)?;
        self.collect_response(resp, options.throw_on_status).await
    }

    /// 流式上传本地文件（不整块进内存）。`on_progress` 收 (已发送, 总长)，
    /// 每 512 KiB 报一次；返回最终响应与总长。
    pub async fn upload_file(
        &self,
        options: RequestOptions,
        file_path: String,
        on_progress: impl Fn(i64, i64) + Send + Sync + 'static,
        cancelled: impl Fn() -> bool + Send + Sync + 'static,
    ) -> Result<(HttpResponse, i64), HttpError> {
        const PROGRESS_STEP: i64 = 512 * 1024;

        let file = tokio::fs::File::open(&file_path)
            .await
            .map_err(|e| err(HttpErrorKind::Request, format!("open file failed: {e}")))?;
        let total = file
            .metadata()
            .await
            .map_err(|e| err(HttpErrorKind::Request, format!("stat file failed: {e}")))?
            .len() as i64;

        let mut sent: i64 = 0;
        let mut last_report: i64 = 0;
        let stream = tokio_util::io::ReaderStream::new(file).map(move |chunk| {
            // 传输中途取消：给 body 流一个 Err，reqwest 随即中断这次请求。
            if cancelled() {
                return Err(std::io::Error::other("cancelled"));
            }
            if let Ok(bytes) = &chunk {
                sent += bytes.len() as i64;
                if sent - last_report >= PROGRESS_STEP || sent == total {
                    last_report = sent;
                    on_progress(sent, total);
                }
            }
            chunk
        });

        // 显式 content-length：hyper 对带该头的流式 body 走定长编码，接收端才有确定进度。
        let req = self
            .builder(&options)?
            .header(reqwest::header::CONTENT_LENGTH, total)
            .body(reqwest::Body::wrap_stream(stream));

        let resp = req.send().await.map_err(map_reqwest_err)?;
        let response = self.collect_response(resp, options.throw_on_status).await?;
        Ok((response, total))
    }

    async fn collect_response(
        &self,
        resp: reqwest::Response,
        throw_on_status: Option<bool>,
    ) -> Result<HttpResponse, HttpError> {
        let status = resp.status();
        let headers = resp
            .headers()
            .iter()
            .map(|(k, v)| KeyValue {
                key: k.as_str().to_string(),
                value: v.to_str().unwrap_or_default().to_string(),
            })
            .collect();

        if throw_on_status.unwrap_or(self.throw_on_status) && !status.is_success() {
            return Err(HttpError {
                kind: HttpErrorKind::Status,
                status: Some(status.as_u16()),
                message: format!("HTTP {}", status.as_u16()),
            });
        }

        let body = crate::client::read_body(resp)
            .await
            .map_err(map_reqwest_err)?;
        Ok(HttpResponse {
            status: status.as_u16(),
            headers,
            body,
        })
    }
}

/// 文件上传过程事件：进度事件 [response] 为 None，最后一条携带最终响应。
#[derive(Clone)]
pub struct UploadEvent {
    pub sent: i64,
    pub total: i64,
    pub response: Option<HttpResponse>,
}
