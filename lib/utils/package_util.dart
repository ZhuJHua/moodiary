import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class PackageUtil {
  //获取版本信息
  static Future<PackageInfo> getPackageInfo() async {
    return await PackageInfo.fromPlatform();
  }

  static Future<BaseDeviceInfo> getInfo() async {
    DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    return await deviceInfoPlugin.deviceInfo;
  }
}
