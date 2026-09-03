/// sync 门面：WebDAV / S3 对象读写。只给 `moodiary_sync`。
///
/// 任何调用前先 `await MoodiaryRust.ensureInitialized()`。
library;

export 'src/runtime.dart';
export 'src/rust/api/s3.dart';
export 'src/rust/api/webdav.dart';
