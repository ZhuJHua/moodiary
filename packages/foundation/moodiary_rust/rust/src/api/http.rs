//! 基于 reqwest 的通用 HTTP 客户端，经 flutter_rust_bridge 暴露给 Dart，替代原 Dio。
//! 设计参考 rhttp（可复用连接池的 client + 一次 request 调用），但只覆盖当前所需的
//! 「核心」子集：全动词、query、headers、字节请求体、字节响应、超时、重定向上限、
//! 按状态码抛错。请求体的 json / form / text 编码与响应体的解码均放在 Dart 侧完成，
//! 这里只做「字节进、字节出」的透明转发，FFI 面尽量薄。

use std::time::Duration;

use flutter_rust_bridge::frb;

use crate::http_client::platform_client_builder;

/// HTTP 方法。跨 FFI 的枚举，映射到 reqwest::Method。
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

/// 有序键值对，用于 query / 请求头 / 响应头。用结构体而非 map 以保留顺序与重复键
/// （响应头如 set-cookie 可重复）。
pub struct KeyValue {
    pub key: String,
    pub value: String,
}

/// 建 client 时的设置。为空的字段走 reqwest 默认。
pub struct ClientSettings {
    /// 相对 url 的基准；为 None 时所有请求都必须传绝对 url。
    pub base_url: Option<String>,
    pub connect_timeout_ms: Option<u32>,
    /// 整体超时（含读取响应）。单次请求可再覆盖。
    pub timeout_ms: Option<u32>,
    pub user_agent: Option<String>,
    /// None=reqwest 默认(最多 10 跳)，Some(0)=不跟随重定向，Some(n)=最多 n 跳。
    pub max_redirects: Option<u32>,
    /// 为 true 时非 2xx 响应抛 [HttpErrorKind::Status]（对齐旧 Dio 行为）。
    pub throw_on_status: bool,
}

/// 一次响应。body 为原始字节，解码交给 Dart。
pub struct HttpResponse {
    pub status: u16,
    pub headers: Vec<KeyValue>,
    pub body: Vec<u8>,
}

/// 错误类别，供 Dart 侧映射成 typed 异常（对齐 rhttp 的异常分型）。
pub enum HttpErrorKind {
    /// 连接或读取超时。
    Timeout,
    /// 建立连接失败（DNS / 拒绝 / 网络不可达）。
    Connect,
    /// 构造请求阶段出错（非法 url / 头等）。
    Request,
    /// 超过重定向上限。
    Redirect,
    /// 读取 / 解码响应体失败。
    Decode,
    /// throw_on_status 打开时的非 2xx 响应。
    Status,
    /// 其它未归类错误。
    Unknown,
}

/// 跨 FFI 的错误对象。作为 `Result` 的 Err 分支返回，Dart 侧 catch 后转 HttpException。
pub struct HttpError {
    pub kind: HttpErrorKind,
    /// 有 HTTP 响应时的状态码。
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

/// 可复用的 HTTP 客户端（内部持有 reqwest::Client 的连接池）。作为 opaque 句柄常驻
/// Dart 侧，多次请求复用同一连接池。
#[frb(opaque)]
pub struct HttpClient {
    inner: reqwest::Client,
    base_url: Option<String>,
    throw_on_status: bool,
}

impl HttpClient {
    pub fn new(settings: ClientSettings) -> Result<HttpClient, HttpError> {
        // platform_client_builder 处理 Android 上 rustls-platform-verifier 需初始化的坑：
        // 仅 Android 换成内置 webpki 根，其余平台走 reqwest 默认 TLS（认系统信任库）。
        let mut builder = platform_client_builder()
            .map_err(|e| err(HttpErrorKind::Unknown, e.to_string()))?;
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

    pub async fn request(
        &self,
        method: HttpMethod,
        url: String,
        query: Vec<KeyValue>,
        headers: Vec<KeyValue>,
        body: Option<Vec<u8>>,
        timeout_ms: Option<u32>,
    ) -> Result<HttpResponse, HttpError> {
        let mut full_url = self.resolve_url(&url)?;
        if !query.is_empty() {
            // reqwest 关了默认特性，RequestBuilder::query 不可用；直接往 Url 追加
            // query（application/x-www-form-urlencoded，语义一致）。
            let mut pairs = full_url.query_pairs_mut();
            for kv in &query {
                pairs.append_pair(&kv.key, &kv.value);
            }
        }
        let mut req = self.inner.request(method.into(), full_url);
        for h in headers {
            req = req.header(h.key, h.value);
        }
        if let Some(ms) = timeout_ms {
            req = req.timeout(Duration::from_millis(ms as u64));
        }
        if let Some(b) = body {
            req = req.body(b);
        }

        let resp = req.send().await.map_err(map_reqwest_err)?;
        let status = resp.status();
        let headers = resp
            .headers()
            .iter()
            .map(|(k, v)| KeyValue {
                key: k.as_str().to_string(),
                value: v.to_str().unwrap_or_default().to_string(),
            })
            .collect();

        if self.throw_on_status && !status.is_success() {
            return Err(HttpError {
                kind: HttpErrorKind::Status,
                status: Some(status.as_u16()),
                message: format!("HTTP {}", status.as_u16()),
            });
        }

        let body = resp.bytes().await.map_err(map_reqwest_err)?.to_vec();
        Ok(HttpResponse {
            status: status.as_u16(),
            headers,
            body,
        })
    }
}
