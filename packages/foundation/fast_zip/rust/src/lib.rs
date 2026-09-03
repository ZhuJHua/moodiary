//! zip 归档：写（可选 AES 加密、stored）与解压（带取消）。`api/` 是 FRB 门面，唯一认识
//! `flutter_rust_bridge` 的地方；`archive.rs` 只收纯闭包。

pub mod api;
pub mod archive;
mod frb_generated;
