import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkUtil {
  // 检查是否连接到wifi
  static Future<bool> isWifiConnected() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult.contains(ConnectivityResult.wifi);
  }

  // 获取设备ip地址
  static Future<String?> getDeviceIP() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.isNotEmpty) {
      if (connectivityResult.contains(ConnectivityResult.wifi)) {
        final info = NetworkInfo();
        return info.getWifiIP();
      } else {
        for (var interface in await NetworkInterface.list()) {
          for (var address in interface.addresses) {
            if (address.type == InternetAddressType.IPv4) {
              return address.address;
            }
          }
        }
      }
    }
    return null;
  }
}
