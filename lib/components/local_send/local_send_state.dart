import 'package:get/get.dart';

class LocalSendState {
  String wifiSSID = '';

  String deviceIpAddress = '';

  int transferPort = 54321;
  int scanPort = 50001;

  RxBool findingServer = false.obs;

  RxString serverIp = ''.obs;
  RxnInt serverPort = RxnInt();

  String type = 'send';

  LocalSendState();
}
