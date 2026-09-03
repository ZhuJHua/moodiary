//! Moodiary 的网络业务库：一套 reqwest / rustls / tokio 底座，上面三层——
//! `http`（客户端 + hyper 应用内服务端）→ `sync`（WebDAV / S3 对象读写）/ `llm`（rig 流式对话）。
//! 同一个库的理由只有一个：它们共享整套网络底座（实测 2 MiB `.text`）与一个连接池；
//! 与网络无关的能力各自成包（fast_*）。`api/` 是 FRB 门面，唯一认识 `flutter_rust_bridge` 的地方。

pub mod api;
mod frb_generated;
pub mod http;
pub mod llm;
pub mod sync;
