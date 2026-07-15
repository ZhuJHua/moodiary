/// moodiary_rust 统一导出：Rust FFI 的对外 Dart 接口。
///
/// 用法:
///   import 'package:moodiary_rust/moodiary_rust.dart';            // 直接用 uuidV7() 等
///   import 'package:moodiary_rust/moodiary_rust.dart' as rust;    // 用 rust.imageThumbnail() 等
///
/// `RustLib.init()` 在 app 启动时调用一次（见 main.dart）。绑定（lib/src/rust/）由
/// `flutter_rust_bridge_codegen generate`（在本包目录内运行）生成。
library;

export 'src/rust/frb_generated.dart' show RustLib;
export 'src/rust/api/assistant.dart';
export 'src/rust/api/audio.dart';
export 'src/rust/api/crypto.dart';
export 'src/rust/api/font.dart';
export 'src/rust/api/http.dart';
export 'src/rust/api/http_server.dart';
export 'src/rust/api/image.dart';
export 'src/rust/api/s3.dart';
export 'src/rust/api/text.dart';
export 'src/rust/api/uuid.dart';
export 'src/rust/api/webdav.dart';
export 'src/rust/api/zip.dart';
