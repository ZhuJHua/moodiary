//! 加密原语：AES-256-GCM 对称加密、Argon2id 密钥派生与密码哈希。
//! `api/` 是 FRB 门面，唯一认识 `flutter_rust_bridge` 的地方；其余模块是纯 Rust。

pub mod aes;
pub mod api;
mod frb_generated;
pub mod password;
