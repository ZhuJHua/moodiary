import 'package:local_auth/local_auth.dart';

class BiometricAuth {
  static final LocalAuthentication _authentication = LocalAuthentication();

  /// [reason] 是系统弹窗里显示给用户的那句话，由调用方给 —— 本包是零 moodiary_*
  /// 依赖的 core 叶子，拿不到 `moodiary_i18n`。
  static Future<bool> check({required String reason}) async {
    return await _authentication.authenticate(
      localizedReason: reason,
      biometricOnly: true,
      sensitiveTransaction: true,
      persistAcrossBackgrounding: true,
    );
  }

  /// 真机冷启动实测 26–48ms（BiometricManager 的 binder 调用），**别放回启动路径**；
  /// 锁页 / 设置项用到时再探测。个别机型/系统状态下 local_auth 会抛 PlatformException，
  /// 探测失败一律按「不支持生物识别」处理（曾在启动链上炸到 main，App 黑屏）。
  static Future<bool> canCheckBiometrics() async {
    try {
      return await _authentication.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }
}
