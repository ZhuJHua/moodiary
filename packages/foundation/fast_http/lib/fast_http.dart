/// 快速 HTTP：reqwest 客户端 / hyper 应用内服务端 / WebDAV / S3，原生侧是自带的
/// `libfasthttp`，经 flutter_rust_bridge 调用。
///
/// 用法：任何调用前先 `await FastHttp.ensureInitialized()`（含 `CancelToken()` 这类同步构造）。
library;

export 'src/runtime.dart';
export 'src/rust/api/cancel.dart';
export 'src/rust/api/http.dart';
export 'src/rust/api/http_server.dart';
export 'src/rust/api/s3.dart';
export 'src/rust/api/webdav.dart';
export 'src/rust/frb_generated.dart' show FastHttpLib;
