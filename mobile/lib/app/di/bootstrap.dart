import 'dart:async';
import 'dart:io';

import 'package:fast_image/fast_image.dart';
import 'package:flutter/widgets.dart';
import 'package:moodiary_components/moodiary_components.dart'
    show LegacyMoodSceneLabel;
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_mcp/moodiary_mcp.dart'
    show mcpKeepAliveProvider, mcpServiceProvider;
import 'package:moodiary_migration/moodiary_migration.dart'
    show
        EditorMigrationService,
        StartupMigrationCoordinator,
        startupMigrationCoordinatorProvider;
import 'package:moodiary_ml/moodiary_ml.dart' show EmbeddingModelManager;
import 'package:moodiary_native/moodiary_native.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_reminder/moodiary_reminder.dart';
import 'package:moodiary_semantic/moodiary_semantic.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_sync/moodiary_sync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bootstrap.g.dart';

@Riverpod(keepAlive: true)
Future<void> _platformDirectories(Ref ref) => PlatformService.get().init();

Future<void> bootstrapPlatform(Ref ref) async {
  await ref.read(_platformDirectoriesProvider.future);
  await AppFiles.initCreateDir();
  FastImageRuntime.configure(
    imageDir: AppFiles.imageDir,
    thumbDir: AppFiles.imageThumbDir,
    log: logger.d,
  );
  AppLogger.configure(logFilePath: AppFiles.getErrorLogPath());
}

Future<void> resumeDataStartup(Ref ref) =>
    ref.read(_dataStartupProvider.future);

@Riverpod(keepAlive: true)
Future<void> _dataStartup(Ref ref) async {
  try {
    await StartupMigrationCoordinator.migrateVersion(
      ref.read(kvStorageProvider),
    );
  } catch (error, stack) {
    logger.e('version migration failed', error: error, stackTrace: stack);
  }
  try {
    await ref
        .read(startupMigrationCoordinatorProvider)
        .refreshEditorGate(ref.read(diaryRepositoryProvider));
  } catch (error, stack) {
    logger.e('migration gate probe failed', error: error, stackTrace: stack);
  }
  try {
    await ref.read(reminderServiceProvider).initialize();
  } catch (error, stack) {
    logger.e('Reminder initialization failed', error: error, stackTrace: stack);
  }
  final db = ref.read(moodiaryDatabaseProvider);
  await db.applyLegacyMoodScenes((scene) => scene.labelOf(l10n));
  final upgradedFrom = db.upgradedFrom;
  if (upgradedFrom != null) {
    MoodiaryKVs.syncPendingLocal.set(true);
    if (upgradedFrom < 3) MoodiaryKVs.pendingMoodNotice.set(true);
  }
  await ref.read(syncOperationGuardProvider).tryRun(purgeSyncMediaTemp);
  ref.read(autoSyncWatcherProvider).start();
  ref.read(embedQueueWatcherProvider).start();
  runStartupMaintenance(ref);
}

void runStartupMaintenance(Ref ref) {
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!ref.mounted) return;
    unawaited(purgeExpiredTombstones(ref.read(tombstoneRepositoryProvider)));
    unawaited(ref.read(embedIndexServiceProvider).drain());
    if (!Platform.isAndroid) return;
    await ref.read(mcpKeepAliveProvider).restore();
    await ref.read(mcpServiceProvider).restore();
  });
}

@Riverpod(keepAlive: true)
Future<void> Function() resetDataAction(Ref ref) =>
    () => resetAllData(ref);

Future<void> resetAllData(Ref ref) async {
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
  await step(
    'platform.directories',
    () => ref.read(_platformDirectoriesProvider.future),
  );
  Future<void> deleteDbFiles() => Future.wait([
    for (final suffix in const ['', '-wal', '-shm', '-journal'])
      AppFiles.deleteFile(
        AppFiles.getRealPath('database', 'moodiary.db$suffix'),
      ),
  ]);

  MoodiaryDatabase? database;
  if (ref.exists(moodiaryDatabaseAsyncProvider)) {
    try {
      database = await ref.read(moodiaryDatabaseAsyncProvider.future);
    } catch (error, stack) {
      logger.e(
        'Resetting files after database open failed',
        error: error,
        stackTrace: stack,
      );
    }
  }
  var databaseCleared = false;
  if (database != null) {
    try {
      await database.clearAll();
      databaseCleared = true;
    } catch (error, stack) {
      logger.e(
        'resetAllData: database.clearAll failed; closing and deleting files',
        error: error,
        stackTrace: stack,
      );
      if (ref.exists(autoSyncWatcherProvider)) {
        await step(
          'autoSyncWatcher.dispose',
          () => ref.read(autoSyncWatcherProvider).dispose(),
        );
      }
      if (ref.exists(embedQueueWatcherProvider)) {
        await step(
          'embedQueueWatcher.dispose',
          () => ref.read(embedQueueWatcherProvider).dispose(),
        );
      }
      try {
        await database.close();
        await deleteDbFiles();
        databaseCleared = true;
      } catch (fallbackError, fallbackStack) {
        logger.e(
          'resetAllData: database.close/deleteFiles failed',
          error: fallbackError,
          stackTrace: fallbackStack,
        );
        failed.add('database.clearAll');
      }
    }
  } else {
    try {
      await deleteDbFiles();
      databaseCleared = true;
    } catch (error, stack) {
      logger.e(
        'resetAllData: database.deleteFiles failed',
        error: error,
        stackTrace: stack,
      );
      failed.add('database.deleteFiles');
    }
  }
  if (!databaseCleared) {
    throw StateError('resetAllData: ${failed.join(', ')} failed');
  }
  if (KVStore.isInstalled) {
    await step('kv.clear', () async => KVStore.instance.clear());
  } else {
    await step(
      'kv.deleteDir',
      () => AppFiles.deleteDir(AppFiles.getRealPath('mmkv', '')),
    );
  }
  await Future.wait([
    if (SecureKVStore.isInstalled)
      step('secureKv.clear', SecureKVStore.instance.clear)
    else
      step(
        'secureKv.clear',
        () async => (await FlutterSecureStorageKVStorage.create()).clear(),
      ),
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
