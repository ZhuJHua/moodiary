import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:refreshed/refreshed.dart';

import 'local_send_state.dart';

Future<String?> getDeviceIP() async {
  // 获取当前的连接状态
  var connectivityResult = await Connectivity().checkConnectivity();

  if (connectivityResult.isNotEmpty) {
    // 如果当前连接到wifi
    if (connectivityResult.contains(ConnectivityResult.wifi)) {
      final info = NetworkInfo();
      return info.getWifiIP();
    } else {
      // 获取所有网络接口
      for (var interface in await NetworkInterface.list()) {
        // 检查接口是否有 IPv4 地址
        for (var address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4) {
            return address.address; // 返回第一个有效的 IPv4 地址
          }
        }
      }
    }
  }

  return null; // 未连接网络或无法获取 IP 地址
}

class LocalSendLogic extends GetxController {
  final LocalSendState state = LocalSendState();

  @override
  void onReady() async {
    await getWifiInfo();
    super.onReady();
  }

  Future<void> getWifiInfo() async {
    state.deviceIpAddress = (await getDeviceIP()) ?? '无法获取';
    update(['WifiInfo']);
  }

  // // client
  // Future<void> findServer() async {
  //   state.findingServer.value = true;
  //   var serverInfo = await localSendClient.findServer();
  //   if (serverInfo != null) {
  //     state.serverIp.value = serverInfo['ip'];
  //     state.serverPort.value = serverInfo['port'];
  //     state.findingServer.value = false;
  //   }
  // }

  void showInfo() {
    state.showInfo = !state.showInfo;
    update(['Info']);
  }

  void changeType(String value) {
    state.type = value;
    update(['SegmentButton', 'Panel']);
  }
}
