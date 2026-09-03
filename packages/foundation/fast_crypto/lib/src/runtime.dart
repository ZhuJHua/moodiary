import 'rust/frb_generated.dart';

/// 延迟装载：第一次真的要加解密时才 dlopen `libfastcrypto`。
abstract final class FastCrypto {
  static Future<void>? _init;

  /// 幂等；并发调用共用一个 Future（FRB 的 `init` 不允许调第二次）。
  /// 失败后放开缓存，下次再试。
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
