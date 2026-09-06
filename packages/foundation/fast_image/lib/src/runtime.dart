import 'rust/frb_generated.dart';

abstract final class FastImageRuntime {
  static String? _imageDir;
  static String? _thumbDir;
  static void Function(String message) _log = (_) {};

  // 顺序依赖：先 init() 装载原生库，configure() 之后才能用 FastImageDerivatives / FastImage
  static Future<void> init() => FastImageLib.init();

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

  static void log(String message) => _log(message);
}
