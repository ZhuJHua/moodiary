//! LLM 对话：rig 的流式多轮 + 工具调用。Rust 侧完全通用、不认识「日记」——工具定义作为数据
//! 从 Dart 传入，工具执行（含权限闸门）由 Dart 回调完成。`api/` 是 FRB 门面，唯一认识
//! `flutter_rust_bridge` 的地方；`chat.rs` 只收纯闭包。

pub mod api;
pub mod chat;
mod frb_generated;
mod http_client;
