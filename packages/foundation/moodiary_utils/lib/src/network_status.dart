import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkStatus {
  static Future<bool> isWifiConnected() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult.contains(ConnectivityResult.wifi);
  }

  static Future<bool> isNetworkConnected() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  /// 本机所有非回环 IPv4（Wi-Fi / 以太网等）。
  static Future<List<String>> getLocalIPv4s() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    return [
      for (final interface in interfaces)
        for (final address in interface.addresses) address.address,
    ];
  }

  static Future<String?> getDeviceIP() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.isEmpty ||
        connectivityResult.contains(ConnectivityResult.none)) {
      return null;
    }
    if (connectivityResult.contains(ConnectivityResult.wifi)) {
      // Android 13+ 底层 WifiManager.getConnectionInfo() 被权限拦截返回 null，
      // 回落到接口枚举。
      final ip = await NetworkInfo().getWifiIP();
      if (ip != null && ip.isNotEmpty) return ip;
    }
    final ips = await getLocalIPv4s();
    return ips.isEmpty ? null : ips.first;
  }
}
