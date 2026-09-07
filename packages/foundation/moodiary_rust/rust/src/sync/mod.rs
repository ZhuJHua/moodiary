pub mod s3;
pub mod webdav;

pub(crate) fn kind_of_status(status: u16) -> &'static str {
    match status {
        401 | 403 => "auth",
        404 => "not_found",
        500..=599 => "server",
        _ => "http",
    }
}

pub(crate) fn kind_of_reqwest(e: &reqwest::Error) -> &'static str {
    if let Some(status) = e.status() {
        return kind_of_status(status.as_u16());
    }
    if e.is_connect() || e.is_timeout() || e.is_request() {
        return "network";
    }
    "unknown"
}

pub(crate) fn tagged(kind: &str, msg: impl std::fmt::Display) -> anyhow::Error {
    anyhow::anyhow!("[{kind}] {msg}")
}
