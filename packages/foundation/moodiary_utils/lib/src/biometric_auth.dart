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
    return await _authentication.canCheckBiometrics;
  }
}
