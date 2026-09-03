import 'rust/frb_generated.dart';

/// fast_image 的运行时配置：包本身不认识 App 的目录布局与日志，组合根在启动时注入。
///
/// 顺序：[init]（装载 libfastimage）→ [configure]（目录就绪后）→ 才能用 [FastImageDerivatives]
/// 与 [FastImage]。
abstract final class FastImageRuntime {
  static String? _imageDir;
  static String? _thumbDir;
  static void Function(String message) _log = (_) {};

  /// 装载原生库。启动最早做，之后任何一步都可以打 Rust。
  static Future<void> init() => FastImageLib.init();

  /// 原件目录与派生物目录（绝对路径）。派生物只给 [imageDir] 里的文件算。
  static void configure({
    required String imageDir,
    required String thumbDir,
    void Function(String message)? log,
  }) {
    _imageDir = imageDir;
    _thumbDir = thumbDir;
    if (log != null) _log = log;
  }

  static String get imageDir =>
      _imageDir ?? (throw StateError('FastImageRuntime.configure 还没调用'));

  static String get thumbDir =>
      _thumbDir ?? (throw StateError('FastImageRuntime.configure 还没调用'));

  /// 调试日志（失败路径才打）。
  static void log(String message) => _log(message);
}
