import 'package:get/get.dart';

class LocalSendState {
  String deviceIpAddress = '';

  int transferPort = 54321;
  int scanPort = 50001;


  String type = 'send';

  bool showInfo = false;

  LocalSendState();
}
