import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class PackageUtil {
  static Future<PackageInfo> getPackageInfo() async {
    return await PackageInfo.fromPlatform();
  }

  static Future<BaseDeviceInfo> getInfo() async {
    final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
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

  /// 面向用户展示的设备名（局域网发现等场景）。iOS 16+ 无特殊授权时返回通用
  /// 名称（如「iPhone」），可接受。
  static Future<String> getDeviceName() async {
    final plugin = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) return (await plugin.androidInfo).model;
      if (Platform.isIOS) return (await plugin.iosInfo).name;
      if (Platform.isMacOS) return (await plugin.macOsInfo).computerName;
      if (Platform.isWindows) return (await plugin.windowsInfo).computerName;
      if (Platform.isLinux) return (await plugin.linuxInfo).name;
    } catch (_) {}
    return 'Moodiary';
  }
}
