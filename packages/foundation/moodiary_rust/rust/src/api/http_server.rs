use anyhow::Result;
use flutter_rust_bridge::{DartFnFuture, frb};
use std::sync::Arc;

use crate::api::http::KeyValue;

pub use crate::http::server::{HttpServerRequest, HttpServerResponse};

#[frb(mirror(HttpServerRequest))]
pub struct _HttpServerRequest {
    pub method: String,
    pub path: String,
    pub query: Vec<KeyValue>,
    pub headers: Vec<KeyValue>,
    pub body: Vec<u8>,
    pub body_file_path: Option<String>,
}

#[frb(mirror(HttpServerResponse))]
pub struct _HttpServerResponse {
    pub status: u16,
    pub headers: Vec<KeyValue>,
    pub body: Vec<u8>,
    pub body_file_path: Option<String>,
}

fn fallback_response(error: anyhow::Error) -> HttpServerResponse {
    HttpServerResponse {
        status: 500,
        headers: vec![KeyValue {
            key: "content-type".to_owned(),
            value: "text/plain; charset=utf-8".to_owned(),
        }],
        body: error.to_string().into_bytes(),
        body_file_path: None,
    }
}

#[frb(opaque)]
pub struct HttpServer {
    inner: crate::http::server::HttpServer,
}

impl HttpServer {
    pub async fn start(
        preferred_port: u16,
        loopback_only: bool,
        spool_dir: String,
        // 不能叫 handler：与 FRB 生成代码里的内部调度器字段同名冲突
        on_request: impl Fn(HttpServerRequest) -> DartFnFuture<Result<HttpServerResponse>>
        + Send
        + Sync
        + 'static,
        on_body_progress: impl Fn(i64, i64) -> DartFnFuture<Result<()>> + Send + Sync + 'static,
    ) -> Result<HttpServer> {
        let handler: crate::http::server::HandlerFn = Arc::new(move |req| {
            let call = on_request(req);
            Box::pin(async move { call.await.unwrap_or_else(fallback_response) })
        });
        let progress: crate::http::server::ProgressFn = Arc::new(move |received, total| {
            let call = on_body_progress(received, total);
            Box::pin(async move {
                let _ = call.await;
            })
        });
        Ok(HttpServer {
            inner: crate::http::server::HttpServer::start(
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
