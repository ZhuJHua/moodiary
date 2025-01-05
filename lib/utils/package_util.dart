import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class PackageUtil {
  //获取版本信息
  static Future<PackageInfo> getPackageInfo() async {
    return await PackageInfo.fromPlatform();
  }

  static Future<BaseDeviceInfo> getInfo() async {
    DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      return await deviceInfoPlugin.androidInfo;
    }
    if (Platform.isIOS) {
      return await deviceInfoPlugin.iosInfo;
    }
    if (Platform.isMacOS) {
      return await deviceInfoPlugin.macOsInfo;
    }
    if (Platform.isWindows) {
      return await deviceInfoPlugin.windowsInfo;
    }
    if (Platform.isLinux) {
      return await deviceInfoPlugin.linuxInfo;
    }
    return await deviceInfoPlugin.deviceInfo;
  }
}
