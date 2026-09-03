//! LLM 对话：rig 的流式多轮 + 工具调用。客户端用 `crate::http::client::shared()`——与 WebDAV / S3
//! 共一个 reqwest 连接池，这也是把它和 http 放进同一个库的理由。
pub mod chat;
