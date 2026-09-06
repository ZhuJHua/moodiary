import 'package:local_auth/local_auth.dart';

class BiometricAuth {
  static final LocalAuthentication _authentication = LocalAuthentication();

  static Future<bool> check({required String reason}) async {
    return await _authentication.authenticate(
      localizedReason: reason,
      biometricOnly: true,
      sensitiveTransaction: true,
      persistAcrossBackgrounding: true,
    );
  }

  static Future<bool> canCheckBiometrics() async {
    try {
      return await _authentication.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }
}
