import 'rust/frb_generated.dart';

/// 启动时由组合根装载（搜索索引与迁移都要它）；测试用 `testing.dart` 的替身代替 `libfasttext`。
abstract final class FastText {
  static Future<void>? _init;

  /// 幂等；并发调用共用一个 Future（FRB 的 `init` 不允许调第二次）。
  /// 失败后放开缓存，下次再试。
  static Future<void> ensureInitialized() async {
    if (FastTextLib.instance.initialized) return;
    try {
      await (_init ??= FastTextLib.init());
    } catch (_) {
      _init = null;
      rethrow;
    }
  }
}
