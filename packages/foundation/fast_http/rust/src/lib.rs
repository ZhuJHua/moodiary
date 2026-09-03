//! HTTP 传输：reqwest 客户端（含上传 / 下载流）、hyper 应用内服务端，以及骑在同一个
//! 客户端上的 WebDAV / S3 对象读写。`api/` 是 FRB 门面，唯一认识 `flutter_rust_bridge` 的地方；
//! 其余模块只收纯闭包。

pub mod api;
mod frb_generated;
pub mod http;
pub mod sync;
