/// 快速、分片的图片管线：派生物（缩略图、baseline 副本）、按需区域解码、分片看图页。
/// 原生侧是自带的 `libfastimage`（turbojpeg / libwebp / png），经 flutter_rust_bridge 调用。
///
/// 用法：启动时 [FastImageRuntime.init]，目录就绪后 [FastImageRuntime.configure]。
library;

export 'src/derivatives.dart';
export 'src/provider.dart';
export 'src/runtime.dart';
export 'src/rust/api/image.dart';
export 'src/tile_plan.dart';
export 'src/tile_view.dart';
export 'src/tile_viewer.dart';
