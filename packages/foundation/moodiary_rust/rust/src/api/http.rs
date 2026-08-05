use flutter_rust_bridge::frb;

use crate::frb_generated::StreamSink;

pub use moodiary_http::request::{
    ClientSettings, HttpError, HttpErrorKind, HttpMethod, HttpResponse, KeyValue, RequestOptions,
    UploadEvent,
};

#[frb(mirror(HttpMethod))]
pub enum _HttpMethod {
    Get,
    Post,
    Put,
    Delete,
    Patch,
    Head,
    Options,
}

/// 有序键值对，用于 query / 请求头 / 响应头。用结构体而非 map 以保留顺序与重复键
/// （响应头如 set-cookie 可重复）。
#[frb(mirror(KeyValue))]
pub struct _KeyValue {
    pub key: String,
    pub value: String,
}

#[frb(mirror(ClientSettings))]
pub struct _ClientSettings {
    pub base_url: Option<String>,
    pub connect_timeout_ms: Option<u32>,
    pub timeout_ms: Option<u32>,
    pub user_agent: Option<String>,
    /// None=reqwest 默认(最多 10 跳)，Some(0)=不跟随重定向，Some(n)=最多 n 跳。
    pub max_redirects: Option<u32>,
    /// 为 true 时非 2xx 响应抛 [HttpErrorKind::Status]（对齐旧 Dio 行为）。
    pub throw_on_status: bool,
}

#[frb(mirror(RequestOptions))]
pub struct _RequestOptions {
    pub method: HttpMethod,
    pub url: String,
    pub query: Vec<KeyValue>,
    pub headers: Vec<KeyValue>,
    pub timeout_ms: Option<u32>,
    /// 覆盖 client 级 throw_on_status；None 沿用。
    pub throw_on_status: Option<bool>,
}

#[frb(mirror(HttpResponse))]
pub struct _HttpResponse {
    pub status: u16,
    pub headers: Vec<KeyValue>,
    pub body: Vec<u8>,
}

#[frb(mirror(HttpErrorKind))]
pub enum _HttpErrorKind {
    Timeout,
    Connect,
    Request,
    Redirect,
    Decode,
    Status,
    Unknown,
}

#[frb(mirror(HttpError))]
pub struct _HttpError {
    pub kind: HttpErrorKind,
    pub status: Option<u16>,
    pub message: String,
}

/// 文件上传过程事件：进度事件 [response] 为 None，最后一条携带最终响应。
#[frb(mirror(UploadEvent))]
pub struct _UploadEvent {
    pub sent: i64,
    pub total: i64,
    pub response: Option<HttpResponse>,
}

#[frb(opaque)]
pub struct HttpClient {
    inner: moodiary_http::request::HttpClient,
}

impl HttpClient {
    pub fn new(settings: ClientSettings) -> Result<HttpClient, HttpError> {
        Ok(HttpClient {
            inner: moodiary_http::request::HttpClient::new(settings)?,
        })
    }

    pub async fn request(
        &self,
        options: RequestOptions,
        body: Option<Vec<u8>>,
    ) -> Result<HttpResponse, HttpError> {
        self.inner.request(options, body).await
    }

    /// 流式上传本地文件（不整块进内存）。进度经 [sink] 回报（`response` 为 None），
    /// 最后一条事件携带最终响应。
    pub async fn upload_file(
        &self,
        sink: StreamSink<UploadEvent>,
        options: RequestOptions,
        file_path: String,
    ) -> Result<(), HttpError> {
        let progress = sink.clone();
        let (response, total) = self
            .inner
            .upload_file(options, file_path, move |sent, total| {
                let _ = progress.add(UploadEvent {
                    sent,
                    total,
                    response: None,
                });
            })
            .await?;
        let _ = sink.add(UploadEvent {
            sent: total,
            total,
            response: Some(response),
        });
        Ok(())
    }
}
