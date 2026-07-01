import 'dart:async';

import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary/feature/sync/application/auto_sync_watcher.dart';
import 'package:moodiary/feature/sync/data/sync_logger.dart';
import 'package:moodiary/feature/sync/data/sync_registry.dart';
import 'package:moodiary/feature/assistant/data/assistant.dart';
import 'package:moodiary/feature/assistant/data/impl/rig_assistant.dart';

Future<void> registerService() async {
  getIt.registerSingleton<IHttpClient>(
    DioHttpClient(onError: (message) => toast.error(message: message)),
  );
  getIt.registerSingleton<AssistantService>(RigAssistantService());
  // 必须在 registerRemoteSync 之前注册，引擎构造时会用到。
  getIt.registerSingleton<SyncLogger>(await SyncLogger.create());
  await registerRemoteSync();
  final autoSync = AutoSyncWatcher.create();
  autoSync.start();
  getIt.registerSingleton<AutoSyncWatcher>(autoSync);
  // 启动恢复：排空上次未完成的「待重索引」队列（崩溃/被杀残留），不阻塞启动。
  unawaited(DiaryRepository.get().drainReindexQueue());
}
