use anyhow::Result;
use flutter_rust_bridge::{DartFnFuture, frb};
use std::sync::Arc;

use crate::api::http::KeyValue;

pub use moodiary_http::server::{HttpServerRequest, HttpServerResponse};

#[frb(mirror(HttpServerRequest))]
pub struct _HttpServerRequest {
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
#[frb(mirror(HttpServerResponse))]
pub struct _HttpServerResponse {
    pub status: u16,
    pub headers: Vec<KeyValue>,
    pub body: Vec<u8>,
    pub body_file_path: Option<String>,
}

#[frb(opaque)]
pub struct HttpServer {
    inner: moodiary_http::server::HttpServer,
}

impl HttpServer {
    pub async fn start(
        preferred_port: u16,
        loopback_only: bool,
        spool_dir: String,
        // 不叫 handler：会与 FRB 生成代码里的内部调度器字段同名冲突。
        on_request: impl Fn(HttpServerRequest) -> DartFnFuture<HttpServerResponse>
        + Send
        + Sync
        + 'static,
        on_body_progress: impl Fn(i64, i64) -> DartFnFuture<()> + Send + Sync + 'static,
    ) -> Result<HttpServer> {
        let handler: moodiary_http::server::HandlerFn =
            Arc::new(move |req| Box::pin(on_request(req)));
        let progress: moodiary_http::server::ProgressFn =
            Arc::new(move |received, total| Box::pin(on_body_progress(received, total)));
        Ok(HttpServer {
            inner: moodiary_http::server::HttpServer::start(
                preferred_port,
                loopback_only,
                spool_dir,
                handler,
                progress,
            )
            .await?,
        })
    }

    #[frb(sync)]
    pub fn port(&self) -> u16 {
        self.inner.port()
    }

    #[frb(sync)]
    pub fn stop(&mut self) {
        self.inner.stop();
    }
}
