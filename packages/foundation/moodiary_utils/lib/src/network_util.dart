import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkUtil {
  static Future<bool> isWifiConnected() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult.contains(ConnectivityResult.wifi);
  }

  static Future<bool> isNetworkConnected() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  static Future<String?> getDeviceIP() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.isNotEmpty) {
      if (connectivityResult.contains(ConnectivityResult.wifi)) {
        final info = NetworkInfo();
        return info.getWifiIP();
      } else {
        for (final interface in await NetworkInterface.list()) {
          for (final address in interface.addresses) {
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
