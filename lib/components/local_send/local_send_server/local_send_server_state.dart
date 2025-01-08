import 'package:faker/faker.dart';
import 'package:refreshed/refreshed.dart';

class LocalSendServerState {
  String? serverIp;
  String serverName = Faker().animal.name();

  int scanPort = 50001;
  int transferPort = 54321;

  RxDouble progress = .0.obs;

  RxDouble speed = .0.obs;
  RxInt receiveCount = 0.obs;

  LocalSendServerState();
}
