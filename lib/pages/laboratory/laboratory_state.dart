import 'package:device_info_plus/device_info_plus.dart';

class LaboratoryState {
  late AndroidDeviceInfo? androidInfo;

  late BaseDeviceInfo? deviceInfo;

  //分辨率
  late String display;

  //版本号
  late String version;

  LaboratoryState() {
    display = '';
    version = '';
    androidInfo = null;
    deviceInfo = null;

    ///Initialize variables
  }
}
