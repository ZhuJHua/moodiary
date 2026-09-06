import 'rust/frb_generated.dart';

abstract final class MoodiaryRust {
  static Future<void>? _init;

  // FRB 的 init 不允许调用第二次
  static Future<void> ensureInitialized() async {
    if (RustLib.instance.initialized) return;
    try {
      await (_init ??= RustLib.init());
    } catch (_) {
      _init = null;
      rethrow;
    }
  }
}
