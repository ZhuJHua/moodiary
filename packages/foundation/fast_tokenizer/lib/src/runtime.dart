import 'rust/frb_generated.dart';

abstract final class FastTokenizer {
  static Future<void>? _init;

  // FRB 的 init 不允许调第二次，失败后要重置缓存才能重试
  static Future<void> ensureInitialized() async {
    if (FastTokenizerLib.instance.initialized) return;
    try {
      await (_init ??= FastTokenizerLib.init());
    } catch (_) {
      _init = null;
      rethrow;
    }
  }
}
