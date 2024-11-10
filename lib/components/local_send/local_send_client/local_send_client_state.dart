import 'package:get/get.dart';

class LocalSendClientState {
  int? serverPort;
  String? serverIp;

  int scanPort = 50001;
  Duration broadcastInterval = const Duration(seconds: 3);

  RxDouble progress = .0.obs;
  RxDouble speed = .0.obs;

  bool isFindingServer = false;

  LocalSendClientState();
}
