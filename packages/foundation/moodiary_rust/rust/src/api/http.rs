use anyhow::anyhow;
use flutter_rust_bridge::frb;

use crate::api::cancel::CancelToken;
use crate::frb_generated::StreamSink;

pub use crate::http::KeyValue;
pub use crate::http::request::{
    ClientSettings, HttpMethod, HttpResponse, RequestOptions, UploadEvent,
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
    pub max_redirects: Option<u32>,
    pub throw_on_status: bool,
}

#[frb(mirror(RequestOptions))]
pub struct _RequestOptions {
    pub method: HttpMethod,
    pub url: String,
    pub query: Vec<KeyValue>,
    pub headers: Vec<KeyValue>,
    pub timeout_ms: Option<u32>,
    pub throw_on_status: Option<bool>,
}

#[frb(mirror(HttpResponse))]
pub struct _HttpResponse {
    pub status: u16,
    pub headers: Vec<KeyValue>,
    pub body: Vec<u8>,
}

pub enum HttpErrorKind {
    Timeout,
    Connect,
    Request,
    Redirect,
    Decode,
    Status,
    Unknown,
}

pub struct HttpError {
    pub kind: HttpErrorKind,
    pub status: Option<u16>,
    pub message: String,
}

impl From<crate::http::request::HttpError> for HttpError {
    fn from(e: crate::http::request::HttpError) -> Self {
        HttpError {
            kind: match e.kind {
                crate::http::request::HttpErrorKind::Timeout => HttpErrorKind::Timeout,
                crate::http::request::HttpErrorKind::Connect => HttpErrorKind::Connect,
                crate::http::request::HttpErrorKind::Request => HttpErrorKind::Request,
                crate::http::request::HttpErrorKind::Redirect => HttpErrorKind::Redirect,
                crate::http::request::HttpErrorKind::Decode => HttpErrorKind::Decode,
                crate::http::request::HttpErrorKind::Status => HttpErrorKind::Status,
                crate::http::request::HttpErrorKind::Unknown => HttpErrorKind::Unknown,
            },
            status: e.status,
            message: e.message,
        }
    }
}

#[frb(mirror(UploadEvent))]
pub struct _UploadEvent {
    pub sent: i64,
    pub total: i64,
    pub response: Option<HttpResponse>,
}

#[frb(opaque)]
pub struct HttpClient {
    inner: crate::http::request::HttpClient,
}

impl HttpClient {
    pub fn new(settings: ClientSettings) -> Result<HttpClient, HttpError> {
        Ok(HttpClient {
            inner: crate::http::request::HttpClient::new(settings).map_err(HttpError::from)?,
        })
    }

    pub async fn request(
        &self,
        options: RequestOptions,
        body: Option<Vec<u8>>,
    ) -> Result<HttpResponse, HttpError> {
        self.inner
            .request(options, body)
            .await
            .map_err(HttpError::from)
    }

    pub async fn upload_file(
        &self,
        sink: StreamSink<UploadEvent>,
        options: RequestOptions,
        file_path: String,
        cancel: &CancelToken,
    ) -> Result<(), HttpError> {
        let progress = sink.clone();
        let uploaded = self
            .inner
            .upload_file(
                options,
                file_path,
                move |sent, total| {
                    let _ = progress.add(UploadEvent {
                        sent,
                        total,
                        response: None,
                    });
                },
                cancel.checker(),
            )
            .await;
        match uploaded {
            Ok((response, total)) => {
                let _ = sink.add(UploadEvent {
                    sent: total,
                    total,
                    response: Some(response),
                });
            }
            Err(e) => {
                let _ = sink.add_error(anyhow!("{}", e.message));
            }
        }
        Ok(())
    }

    pub async fn download_file(
        &self,
        sink: StreamSink<DownloadEvent>,
        options: RequestOptions,
        dest_path: String,
        cancel: &CancelToken,
    ) -> Result<(), HttpError> {
        let progress = sink.clone();
        let downloaded = self
            .inner
            .download_file(
                options,
                dest_path,
                move |received, total| {
                    let _ = progress.add(DownloadEvent {
                        received,
                        total,
                        done: false,
                    });
                },
                cancel.checker(),
            )
            .await;
        match downloaded {
            Ok(received) => {
                let _ = sink.add(DownloadEvent {
                    received,
                    total: received,
                    done: true,
                });
            }
            Err(e) => {
                let _ = sink.add_error(anyhow!("{}", e.message));
            }
        }
        Ok(())
    }
}

#[derive(Clone)]
pub struct DownloadEvent {
    pub received: i64,
    pub total: i64,
    pub done: bool,
}
