import 'dart:io';

import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

class AuthUtil {
  late final LocalAuthentication _authentication = LocalAuthentication();

  //生物识别
  Future<bool> check() async {
    return await _authentication.authenticate(
      authMessages: [
        const AndroidAuthMessages(
          biometricHint: "",
          biometricNotRecognized: "验证失败",
          biometricSuccess: "验证成功",
          cancelButton: "取消",
          goToSettingsButton: "设置",
          goToSettingsDescription: "请先在系统中开启指纹",
          signInTitle: "扫描您的指纹以继续",
        )
      ],
      localizedReason: '安全验证',
      options: AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
          sensitiveTransaction: true,
          biometricOnly: Platform.isWindows ? false : true),
    );
  }

  //判断是否有硬件
  Future<bool> canCheckBiometrics() async {
    return await _authentication.canCheckBiometrics;
  }
}
