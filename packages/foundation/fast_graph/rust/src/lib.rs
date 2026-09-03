//! 力导向图布局：ForceAtlas2 + Barnes-Hut（`layout.rs`），逐帧流式吐坐标。
//! `ffi.rs` 是 C ABI 门面（裸 `dart:ffi`，不走 FRB），布局跑在自己的线程上、经回调把帧推给 Dart。

pub mod ffi;
pub mod layout;
