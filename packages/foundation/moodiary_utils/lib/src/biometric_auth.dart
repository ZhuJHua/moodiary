import 'package:local_auth/local_auth.dart';

class BiometricAuth {
  static final LocalAuthentication _authentication = LocalAuthentication();

  /// [reason] 是系统弹窗里显示给用户的那句话，由调用方给 —— foundation 是叶子层，
  /// 拿不到 `moodiary_l10n`。
  static Future<bool> check({required String reason}) async {
    return await _authentication.authenticate(
      localizedReason: reason,
      biometricOnly: true,
      sensitiveTransaction: true,
      persistAcrossBackgrounding: true,
    );
  }

  static Future<bool> canCheckBiometrics() async {
    // 启动链上被 PlatformService.init 的 record `.wait` 并发调用：这里抛出会被包成
    // ParallelWaitError 一路冒到 main，App 黑屏都到不了 runApp。个别机型/系统状态下
    // local_auth 会抛 PlatformException，探测失败一律按「不支持生物识别」处理。
    try {
      return await _authentication.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }
}
