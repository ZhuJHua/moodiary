//! 同步后端：S3 / MinIO 与 WebDAV。只做对象级读写，增量与冲突策略在 Dart 侧的同步引擎里。
//!
//! 错误一律经 [`tagged`] 成文：消息以 `[kind]` 开头，kind 是 Dart 侧
//! `SyncErrorKind` 认得的稳定短词（network / auth / not_found / server / http /
//! unknown），其余是给人看的英文明细。FRB 只把 anyhow 当字符串传，状态码与
//! reqwest 的错误类别只有在这里还能分辨，所以分类必须在这一层做完。

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
