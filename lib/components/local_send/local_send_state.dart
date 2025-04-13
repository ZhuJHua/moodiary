import 'package:get/get.dart';

class LocalSendState {
  String deviceIpAddress = '';

  RxInt transferPort = 54321.obs;
  RxInt scanPort = 50001.obs;

  String type = 'send';

  bool showInfo = false;

  LocalSendState();
}
