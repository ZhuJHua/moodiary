/// 快速 zip：写（可选 AES 加密 / stored）与解压（带取消），原生侧是自带的 `libfastzip`，
/// 经 flutter_rust_bridge 调用。
///
/// 用法：任何调用前先 `await FastZip.ensureInitialized()`（含 `CancelToken()` 这类同步构造）。
library;

export 'src/runtime.dart';
export 'src/rust/api/cancel.dart';
export 'src/rust/api/zip.dart';
export 'src/rust/frb_generated.dart' show FastZipLib;
