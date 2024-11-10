import 'package:get/get.dart';

class LocalSendServerState {
  String? serverIp;

  int scanPort = 50001;
  int transferPort = 54321;

  RxDouble progress = .0.obs;

  RxDouble speed = .0.obs;

  LocalSendServerState();
}
