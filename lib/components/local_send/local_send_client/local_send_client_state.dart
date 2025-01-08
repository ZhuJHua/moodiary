import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:refreshed/refreshed.dart';

class LocalSendClientState {
  int? serverPort;
  String? serverIp;
  String? serverName;

  int scanPort = 50001;
  Duration broadcastInterval = const Duration(seconds: 3);

  RxDouble progress = .0.obs;
  RxDouble speed = .0.obs;

  bool isFindingServer = false;

  RxBool isSending = false.obs;
  RxList<Diary> diaryToSend = <Diary>[].obs;
  RxInt sendCount = 0.obs;

  LocalSendClientState();
}
