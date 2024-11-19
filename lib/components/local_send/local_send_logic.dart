import 'package:get/get.dart';
import 'package:network_info_plus/network_info_plus.dart';

import 'local_send_state.dart';

class LocalSendLogic extends GetxController {
  final LocalSendState state = LocalSendState();
  final networkInfo = NetworkInfo();

  @override
  void onReady() async {
    await getWifiInfo();
    super.onReady();
  }

  Future<void> getWifiInfo() async {
    state.deviceIpAddress = (await networkInfo.getWifiIP()) ?? '无法获取';
    state.wifiSSID = (await networkInfo.getWifiName()) ?? '无法获取';
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
