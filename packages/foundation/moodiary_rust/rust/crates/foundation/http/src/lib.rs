//! HTTP 传输原语：客户端（reqwest + rustls）与应用内服务端（hyper）。

pub mod client;
pub mod request;
pub mod server;

/// 有序键值对，用于 query / 请求头 / 响应头。用结构体而非 map 以保留顺序与重复键
/// （响应头如 set-cookie 可重复）。
#[derive(Clone)]
pub struct KeyValue {
    pub key: String,
    pub value: String,
}
