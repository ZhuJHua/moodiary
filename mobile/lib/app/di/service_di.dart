import 'dart:async';

import 'package:moodiary/app/picker/mobile_file_picker.dart';
import 'package:moodiary_assistant/moodiary_assistant.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_sync/moodiary_sync.dart';
import 'package:moodiary_ui/moodiary_ui.dart';

Future<void> registerService() async {
  getIt.registerSingleton<IHttpClient>(
    RustHttpClient(onError: (message) => toast.error(message: message)),
  );
  // 服务器是「按会话起停」的对象（编辑器 / 局域网接收各一），每次 create 新实例。
  getIt.registerFactory<IHttpServer>(RustHttpServer.new);
  getIt.registerSingleton<IFilePicker>(MobileFilePicker());
  // 备份归档的实现在 sync，页面在 export —— 两个 feature 不能互相 import，在这里接上。
  getIt.registerSingleton<IBackupArchive>(const SyncBackupArchive());
  getIt.registerSingleton<AssistantService>(RigAssistantService());
  getIt.registerSingleton<SyncLogger>(await SyncLogger.create());
  await registerRemoteSync();
  final autoSync = AutoSyncWatcher.create();
  autoSync.start();
  getIt.registerSingleton<AutoSyncWatcher>(autoSync);
  unawaited(DiaryRepository.get().drainReindexQueue());
  // 同步墓碑保留窗 GC（默认 90 天）：零后端用户的墓碑因此有界，不无限累积。
  unawaited(purgeExpiredTombstones());
}
