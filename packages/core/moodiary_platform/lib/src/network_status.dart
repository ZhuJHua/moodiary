import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkStatus {
  static Stream<bool> get onlineChanges => Connectivity().onConnectivityChanged
      .map((r) => r.isNotEmpty && !r.contains(ConnectivityResult.none))
      .distinct();

  static Future<bool> isWifiConnected() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult.contains(ConnectivityResult.wifi);
  }

  static Future<bool> isNetworkConnected() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  static Future<List<String>> getLocalIPv4s() async {
    final interfaces = await NetworkInterface.list(type: .IPv4);
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
      // Android 13+ 权限拦截，getWifiIP() 会返回 null
      final ip = await NetworkInfo().getWifiIP();
      if (ip != null && ip.isNotEmpty) return ip;
    }
    final ips = await getLocalIPv4s();
    return ips.isEmpty ? null : ips.first;
  }
}
