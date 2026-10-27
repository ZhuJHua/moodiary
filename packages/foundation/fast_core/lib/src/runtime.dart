import 'rust/frb_generated.dart';

abstract final class FastCore {
  static Future<void>? _init;

  // FRB 的 init 不允许调用第二次
  static Future<void> ensureInitialized() async {
    if (FastCoreLib.instance.initialized) return;
    try {
      await (_init ??= FastCoreLib.init());
    } catch (_) {
      _init = null;
      rethrow;
    }
  }
}
