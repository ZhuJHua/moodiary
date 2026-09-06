import 'rust/frb_generated.dart';

abstract final class FastPress {
  static Future<void>? _init;

  // FRB 的 `init` 不允许调第二次
  static Future<void> ensureInitialized() async {
    if (FastPressLib.instance.initialized) return;
    try {
      await (_init ??= FastPressLib.init());
    } catch (_) {
      _init = null;
      rethrow;
    }
  }
}
