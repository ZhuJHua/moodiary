import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

class BiometricAuth {
  static final LocalAuthentication _authentication = LocalAuthentication();

  static Future<bool> check({
    required String title,
    required String reason,
    required String cancel,
    String? fallback,
  }) async {
    try {
      return await _authentication.authenticate(
        localizedReason: reason,
        authMessages: [
          AndroidAuthMessages(
            signInTitle: title,
            signInHint: '',
            cancelButton: fallback ?? cancel,
          ),
          IOSAuthMessages(
            cancelButton: cancel,
            localizedFallbackTitle: fallback ?? '',
          ),
        ],
        biometricOnly: true,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    }
  }

  static final Future<bool> usesFace = _detectFace();

  static Future<bool> _detectFace() async {
    try {
      final types = await _authentication.getAvailableBiometrics();
      return types.contains(BiometricType.face) &&
          !types.contains(BiometricType.fingerprint);
    } on LocalAuthException {
      return false;
    }
  }

  static Future<bool> canCheckBiometrics() async {
    try {
      return await _authentication.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }
}
