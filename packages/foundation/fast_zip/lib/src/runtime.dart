import 'rust/frb_generated.dart';

abstract final class FastZip {
  static Future<void>? _init;

  // FRB 的 init 不允许调第二次，失败后要重置缓存才能重试
  static Future<void> ensureInitialized() async {
    if (FastZipLib.instance.initialized) return;
    try {
      await (_init ??= FastZipLib.init());
    } catch (_) {
      _init = null;
      rethrow;
    }
  }
}
