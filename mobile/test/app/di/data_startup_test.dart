import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_migration/moodiary_migration.dart';
import 'package:moodiary_mobile/app/di/bootstrap.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_reminder/moodiary_reminder.dart';
import 'package:moodiary_semantic/moodiary_semantic.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:moodiary_sync/moodiary_sync.dart';

class _Database extends Fake implements MoodiaryDatabase {
  _Database(this.upgradedFrom, {this.nextSceneError});
  @override
  final int? upgradedFrom;
  Object? nextSceneError;
  int sceneMigrations = 0;

  @override
  Future<void> applyLegacyMoodScenes(
    String Function(LegacyMoodScene) label,
  ) async {
    final error = nextSceneError;
    if (error != null) {
      nextSceneError = null;
      throw error;
    }
    sceneMigrations++;
  }
}

class _Diaries extends Fake implements DiaryRepository {
  @override
  Future<bool> hasLegacyFormatDiaries() async => false;

  @override
  Future<ReferencedMedia> collectReferencedMedia() async => (
    images: <String>{},
    audios: <String>{},
    videos: <String>{},
    files: <String>{},
  );
}

class _Fonts extends Fake implements FontRepository {}

class _Reminders extends Fake implements ReminderService {
  final entered = Completer<void>();
  final release = Completer<void>();
  int calls = 0;

  @override
  Future<void> initialize() {
    calls++;
    if (!entered.isCompleted) entered.complete();
    return release.future;
  }
}

class _AutoSync extends Fake implements AutoSyncWatcher {
  _AutoSync(this.onStart);
  final void Function() onStart;
  int starts = 0;
  @override
  void start() {
    starts++;
    onStart();
  }
}

class _Tombstones extends Fake implements TombstoneRepository {
  @override
  Future<int> purgeExpired({
    Duration retention = TombstoneRepository.defaultRetention,
    DateTime? now,
  }) async => 0;
}

class _Index extends Fake implements EmbedIndexService {
  @override
  Future<int> drain({int? maxDiaries}) async => 0;
}

class _Queue extends Fake implements EmbedQueueWatcher {
  int starts = 0;
  @override
  void start() => starts++;
}

void _flushPostFrame() {
  final binding = TestWidgetsFlutterBinding.instance;
  binding.handleBeginFrame(Duration.zero);
  binding.handleDrawFrame();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    final root = Directory.systemTemp.createTempSync('mobile-startup-');
    addTearDown(() => root.delete(recursive: true));
    PlatformService.get()
      ..applicationSupportPath = '${root.path}/support'
      ..applicationCachePath = '${root.path}/cache';
    PackageInfo.setMockInitialValues(
      appName: 'Moodiary',
      packageName: 'moodiary',
      version: '3.0.0',
      buildNumber: '100',
      buildSignature: '',
    );
  });
  setUp(() {
    KVStore.installForTesting(MemoryKVStorage());
    addTearDown(KVStore.resetForTesting);
    MoodiaryKVs.syncPendingLocal.set(false);
    MoodiaryKVs.pendingMoodNotice.set(false);
  });

  for (final (version, recover, dirty, notice) in [
    (null, false, false, false),
    (2, true, true, true),
    (3, false, true, false),
    (4, false, true, false),
  ]) {
    test(
      'upgradedFrom=$version, legacy recovery=$recover starts data once and sets upgrade flags',
      () async {
        final database = _Database(version);
        final diaries = _Diaries();
        final reminders = _Reminders();
        final stagingFile =
            File(
                '${PlatformService.get().applicationCachePath}/sync-media/stale.bin',
              )
              ..createSync(recursive: true)
              ..writeAsBytesSync([1, 2, 3]);
        var stagingPresentWhenAutoSyncStarted = false;
        final autoSync = _AutoSync(() {
          stagingPresentWhenAutoSyncStarted = stagingFile.existsSync();
        });
        final queue = _Queue();
        final container = ProviderContainer.test(
          retry: (_, _) => null,
          overrides: [
            moodiaryDatabaseProvider.overrideWithValue(database),
            diaryRepositoryProvider.overrideWithValue(diaries),
            reminderServiceProvider.overrideWithValue(reminders),
            autoSyncWatcherProvider.overrideWithValue(autoSync),
            tombstoneRepositoryProvider.overrideWithValue(_Tombstones()),
            embedIndexServiceProvider.overrideWithValue(_Index()),
            embedQueueWatcherProvider.overrideWithValue(queue),
          ],
        );
        final coordinator = container.read(startupMigrationCoordinatorProvider);
        addTearDown(coordinator.completeEditorMigration);
        final ref = container.read(Provider<Ref>((ref) => ref));
        var activations = 0;
        Future<void> activate() {
          activations++;
          return resumeDataStartup(ref);
        }

        if (recover) {
          final previous = debugDefaultTargetPlatformOverride;
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          addTearDown(() => debugDefaultTargetPlatformOverride = previous);
          final legacy = File(AppFiles.getRealPath('database', 'default.isar'));
          legacy.parent.createSync(recursive: true);
          legacy.writeAsBytesSync([1]);
          expect(await coordinator.probeLegacy(), LegacyDatabaseState.pending);
          await coordinator.startData(activate);
          expect(activations, 0);
          expect(reminders.calls, 0);
          await coordinator.abandonLegacy(diaries: diaries, fonts: _Fonts());
        }
        expect(await coordinator.probeLegacy(), LegacyDatabaseState.none);
        final guard = container.read(syncOperationGuardProvider);
        final purgeDone = guard.changes.firstWhere((busy) => !busy);
        final startup = coordinator.startData(activate);
        await reminders.entered.future;
        // Sequential startup runs legacy scene migration after reminders finish.
        expect(database.sceneMigrations, 0);
        final concurrent = [startup, coordinator.startData(activate)];
        reminders.release.complete();
        await Future.wait(concurrent);
        await coordinator.startData(activate);

        expect(activations, 1);
        expect(reminders.calls, 1);
        expect(database.sceneMigrations, 1);
        expect(stagingPresentWhenAutoSyncStarted, isTrue);
        expect(autoSync.starts, 1);
        expect(queue.starts, 1);
        expect(container.read(migrationGateProvider).canEnterHome, isTrue);
        expect(MoodiaryKVs.syncPendingLocal.get(), dirty);
        expect(MoodiaryKVs.pendingMoodNotice.get(), notice);

        _flushPostFrame();
        await purgeDone;
        expect(stagingFile.existsSync(), isFalse);
      },
    );
  }

  test('retrying startData after a failure re-runs startup and opens the home gate', () async {
    final database = _Database(
      null,
      nextSceneError: StateError('scene migration failed'),
    );
    final diaries = _Diaries();
    final reminders = _Reminders()..release.complete();
    final autoSync = _AutoSync(() {});
    final queue = _Queue();
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        moodiaryDatabaseProvider.overrideWithValue(database),
        diaryRepositoryProvider.overrideWithValue(diaries),
        reminderServiceProvider.overrideWithValue(reminders),
        autoSyncWatcherProvider.overrideWithValue(autoSync),
        tombstoneRepositoryProvider.overrideWithValue(_Tombstones()),
        embedIndexServiceProvider.overrideWithValue(_Index()),
        embedQueueWatcherProvider.overrideWithValue(queue),
      ],
    );
    final coordinator = container.read(startupMigrationCoordinatorProvider);
    addTearDown(coordinator.completeEditorMigration);
    final ref = container.read(Provider<Ref>((ref) => ref));
    var activations = 0;
    Future<void> activate() {
      activations++;
      return resumeDataStartup(ref);
    }

    expect(await coordinator.probeLegacy(), LegacyDatabaseState.none);
    await expectLater(coordinator.startData(activate), throwsStateError);
    expect(activations, 1);
    expect(database.sceneMigrations, 0);
    expect(autoSync.starts, 0);
    expect(queue.starts, 0);
    expect(container.read(migrationGateProvider).canEnterHome, isFalse);

    await coordinator.startData(activate);
    expect(activations, 2);
    expect(database.sceneMigrations, 1);
    expect(autoSync.starts, 1);
    expect(queue.starts, 1);
    expect(container.read(migrationGateProvider).canEnterHome, isTrue);
  });

  test('post-frame sync media purge skips cleanup while sync guard is busy', () async {
    final database = _Database(null);
    final diaries = _Diaries();
    final reminders = _Reminders()..release.complete();
    final stagingFile =
        File(
            '${PlatformService.get().applicationCachePath}/sync-media/active.bin',
          )
          ..createSync(recursive: true)
          ..writeAsBytesSync([4, 5, 6]);
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        moodiaryDatabaseProvider.overrideWithValue(database),
        diaryRepositoryProvider.overrideWithValue(diaries),
        reminderServiceProvider.overrideWithValue(reminders),
        autoSyncWatcherProvider.overrideWithValue(_AutoSync(() {})),
        tombstoneRepositoryProvider.overrideWithValue(_Tombstones()),
        embedIndexServiceProvider.overrideWithValue(_Index()),
        embedQueueWatcherProvider.overrideWithValue(_Queue()),
      ],
    );
    final coordinator = container.read(startupMigrationCoordinatorProvider);
    addTearDown(coordinator.completeEditorMigration);
    final ref = container.read(Provider<Ref>((ref) => ref));
    final guard = container.read(syncOperationGuardProvider);
    final releaseGuard = Completer<void>();
    final activeSync = guard.tryRun(() => releaseGuard.future);
    addTearDown(() {
      if (!releaseGuard.isCompleted) releaseGuard.complete();
    });

    expect(await coordinator.probeLegacy(), LegacyDatabaseState.none);
    await coordinator.startData(() => resumeDataStartup(ref));
    _flushPostFrame();
    await Future<void>.delayed(Duration.zero);

    expect(stagingFile.existsSync(), isTrue);
    releaseGuard.complete();
    await activeSync;
  });
}
