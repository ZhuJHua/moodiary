/// 快速加密原语：AES-256-GCM 与 Argon2id，原生侧是自带的 `libfastcrypto`，
/// 经 flutter_rust_bridge 调用。[Aes] / [Argon2] 每次调用自己保证库已装载，调用方不用 init。
library;

export 'src/crypto.dart';
export 'src/runtime.dart';
export 'src/rust/frb_generated.dart' show FastCryptoLib;
