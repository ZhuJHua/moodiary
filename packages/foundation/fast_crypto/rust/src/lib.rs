//! 加密原语：AES-256-GCM 对称加密、Argon2id 密钥派生与密码哈希。
//! `ffi.rs` 是 C ABI 门面（裸 `dart:ffi`，不走 FRB），其余模块是纯 Rust。

pub mod aes;
pub mod ffi;
pub mod password;
