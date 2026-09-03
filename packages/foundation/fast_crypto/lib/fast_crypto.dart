/// 快速加密原语：AES-256-GCM 与 Argon2id，原生侧是自带的 `libfastcrypto`，
/// 经裸 `dart:ffi`（native assets 的 `@Native`）调用——没有 init，首次调用自动装载。
library;

export 'src/crypto.dart';
