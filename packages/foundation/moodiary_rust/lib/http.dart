/// http 门面：reqwest 客户端 / hyper 应用内服务端 / 取消令牌。只给 `moodiary_http`（core 的端口实现）。
///
/// 任何调用前先 `await MoodiaryRust.ensureInitialized()`（含 `CancelToken()` 这类同步构造）。
library;

export 'src/runtime.dart';
export 'src/rust/api/cancel.dart';
export 'src/rust/api/http.dart';
export 'src/rust/api/http_server.dart';
