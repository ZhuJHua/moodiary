import 'dart:async';

import 'package:moodiary/app/picker/mobile_file_picker.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_sync/moodiary_sync.dart';
import 'package:moodiary_assistant/moodiary_assistant.dart';

Future<void> registerService() async {
  getIt.registerSingleton<IHttpClient>(
    RustHttpClient(onError: (message) => toast.error(message: message)),
  );
  // 服务器是「按会话起停」的对象（编辑器 / 局域网接收各一），每次 create 新实例。
  getIt.registerFactory<IHttpServer>(RustHttpServer.new);
  getIt.registerSingleton<IFilePicker>(MobileFilePicker());
  getIt.registerSingleton<AssistantService>(RigAssistantService());
  getIt.registerSingleton<SyncLogger>(await SyncLogger.create());
  await registerRemoteSync();
  final autoSync = AutoSyncWatcher.create();
  autoSync.start();
  getIt.registerSingleton<AutoSyncWatcher>(autoSync);
  unawaited(DiaryRepository.get().drainReindexQueue());
}
