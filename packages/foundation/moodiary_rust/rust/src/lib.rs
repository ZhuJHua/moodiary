//! Moodiary 的业务 Rust 库。网络三层共享一套 reqwest / rustls / tokio 底座与一个连接池——
//! `http`（客户端 + hyper 应用内服务端）→ `sync`（WebDAV / S3 对象读写）/ `llm`（rig 流式对话）；
//! 另有 `graph`（力导向布局，与网络零共享，只是不值得单独一个库）。
//! 有独立价值的能力各自成包（fast_*）。`api/` 是 FRB 门面，唯一认识 `flutter_rust_bridge` 的地方。

pub mod api;
mod frb_generated;
pub mod graph;
pub mod http;
pub mod llm;
pub mod sync;
