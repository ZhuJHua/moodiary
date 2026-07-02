import 'dart:async';

import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary/feature/sync/application/auto_sync_watcher.dart';
import 'package:moodiary/feature/sync/data/sync_logger.dart';
import 'package:moodiary/feature/sync/data/sync_registry.dart';
import 'package:moodiary_assistant/moodiary_assistant.dart';

Future<void> registerService() async {
  getIt.registerSingleton<IHttpClient>(
    DioHttpClient(onError: (message) => toast.error(message: message)),
  );
  getIt.registerSingleton<AssistantService>(RigAssistantService());
  getIt.registerSingleton<SyncLogger>(await SyncLogger.create());
  await registerRemoteSync();
  final autoSync = AutoSyncWatcher.create();
  autoSync.start();
  getIt.registerSingleton<AutoSyncWatcher>(autoSync);
  unawaited(DiaryRepository.get().drainReindexQueue());
}
