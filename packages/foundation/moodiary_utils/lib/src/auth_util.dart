import 'package:local_auth/local_auth.dart';

class AuthUtil {
  static final LocalAuthentication _authentication = LocalAuthentication();

  static Future<bool> check() async {
    return await _authentication.authenticate(
      localizedReason: '安全验证',
      biometricOnly: true,
      sensitiveTransaction: true,
      persistAcrossBackgrounding: true,
    );
  }

  static Future<bool> canCheckBiometrics() async {
    return await _authentication.canCheckBiometrics;
  }
}
