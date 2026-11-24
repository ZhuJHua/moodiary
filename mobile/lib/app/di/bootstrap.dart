import 'dart:async';
import 'dart:io';

import 'package:fast_image/fast_image.dart';
import 'package:flutter/widgets.dart';
import 'package:moodiary_components/moodiary_components.dart'
    show LegacyMoodSceneLabel;
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_editor/moodiary_editor.dart'
    show EditorMigrationService;
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_mcp/moodiary_mcp.dart' show McpKeepAlive, McpService;
import 'package:moodiary_migration/moodiary_migration.dart'
    show VersionMigrator;
import 'package:moodiary_ml/moodiary_ml.dart' show EmbeddingModelManager;
import 'package:moodiary_native/moodiary_native.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_reminder/moodiary_reminder.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_sync/moodiary_sync.dart';

Future<void> bootstrapPlatform() async {
  await PlatformService.get().init();
  await AppFiles.initCreateDir();
  FastImageRuntime.configure(
    imageDir: AppFiles.imageDir,
    thumbDir: AppFiles.imageThumbDir,
    log: logger.d,
  );
  AppLogger.configure(logFilePath: AppFiles.getErrorLogPath());
}

Future<void> resumeDataStartup() async {
  try {
    await VersionMigrator.run();
  } catch (e, s) {
    logger.e('version migration failed', error: e, stackTrace: s);
  }

  final migrationGateFuture = () async {
    try {
      await EditorMigrationService.refreshRequiresMigration();
    } catch (e, s) {
      logger.e('migration gate probe failed', error: e, stackTrace: s);
    }
  }();
  final syncBackendFuture = () async {
    try {
      await activateSyncProvider();
    } catch (e, s) {
      logger.e('sync provider activation failed', error: e, stackTrace: s);
    }
  }();

  await migrationGateFuture;
  final reminderFuture = () async {
    try {
      await getIt<ReminderService>().initialize();
    } catch (error, stack) {
      logger.e(
        'Reminder initialization failed',
        error: error,
        stackTrace: stack,
      );
    }
  }();
  await getIt<MoodiaryDatabase>().applyLegacyMoodScenes(
    (scene) => scene.labelOf(l10n),
  );
  await syncBackendFuture;
  if (getIt<MoodiaryDatabase>().upgradedFrom != null) {
    MoodiaryKVs.syncPendingLocal.set(true);
  }
  getIt<AutoSyncWatcher>().start();
  runStartupMaintenance();
  await reminderFuture;
  final upgradedFrom = getIt<MoodiaryDatabase>().upgradedFrom;
  if (upgradedFrom != null && upgradedFrom < 3) {
    MoodiaryKVs.pendingMoodNotice.set(true);
  }
}

void runStartupMaintenance() {
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!Platform.isAndroid) return;
    await getIt<McpKeepAlive>().restore();
    await getIt<McpService>().restore();
  });
  unawaited(purgeExpiredTombstones());
  unawaited(purgeSyncMediaTemp());
  unawaited(getIt<EmbedIndexService>().drain());
  getIt<EmbedQueueWatcher>().start();
}

Future<void> resetAllData() async {
  final failed = <String>[];
  Future<void> step(String name, Future<void> Function() run) async {
    try {
      await run();
    } catch (e, s) {
      logger.e('resetAllData: $name failed', error: e, stackTrace: s);
      failed.add(name);
    }
  }

  await step('reminders.cancel', ReminderNotificationsApi().clear);
  var dbCleared = false;
  final db = getIt.maybeGet<MoodiaryDatabase>();
  if (db != null) {
    await step('database.clearAll', () async {
      await db.clearAll();
      dbCleared = true;
    });
  }
  if (!dbCleared) {
    await step(
      'database.deleteFiles',
      () => Future.wait([
        for (final suffix in const ['', '-wal', '-shm', '-journal'])
          AppFiles.deleteFile(
            AppFiles.getRealPath('database', 'moodiary.db$suffix'),
          ),
      ]),
    );
  }
  await step('kv.clear', () async => getIt.maybeGet<IKVStorage>()?.clear());
  await Future.wait([
    step('secureKv.clear', () async {
      await getIt.maybeGet<ISecureKVStorage>()?.clear();
    }),
    step('legacyPrefs.clear', LegacyPrefsKVSource.clearStore),
    step('media.reset', AppFiles.resetUserMediaDirs),
    step('cache.clear', () => AppFiles.clearCache(protectWorkspaces: false)),
    step(
      'editorBackups.delete',
      () => AppFiles.deleteDir(EditorMigrationService.backupDirPath),
    ),
    step(
      'models.delete',
      () => AppFiles.deleteDir(EmbeddingModelManager.modelsDirPath),
    ),
    for (final name in {
      'default.isar',
      'default.isar.lock',
      ...legacyDatabaseBackupNames,
    })
      step(
        'legacy.delete.$name',
        () => AppFiles.deleteFile(AppFiles.getRealPath('database', name)),
      ),
    step(
      'legacyAbandoned.delete',
      () =>
          AppFiles.deleteDir(AppFiles.getRealPath(legacyAbandonedDirName, '')),
    ),
  ]);
  if (failed.isNotEmpty) {
    throw StateError('resetAllData: ${failed.join(', ')} failed');
  }
}
