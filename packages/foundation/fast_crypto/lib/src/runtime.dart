import 'rust/frb_generated.dart';

abstract final class FastCrypto {
  static Future<void>? _init;

  // FRB 的 init 不允许调第二次
  static Future<void> ensureInitialized() async {
    if (FastCryptoLib.instance.initialized) return;
    try {
      await (_init ??= FastCryptoLib.init());
    } catch (_) {
      _init = null;
      rethrow;
    }
  }
}
