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
  _Database(this.upgradedFrom);
  @override
  final int? upgradedFrom;
  int sceneMigrations = 0;

  @override
  Future<void> applyLegacyMoodScenes(
    String Function(LegacyMoodScene) label,
  ) async => sceneMigrations++;
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
  int starts = 0;
  @override
  void start() => starts++;
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
        final autoSync = _AutoSync();
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
        final startup = coordinator.startData(activate);
        await reminders.entered.future;
        // Independent DB startup work overlaps reminder initialization.
        expect(database.sceneMigrations, 1);
        final concurrent = [
          startup,
          coordinator.startData(activate),
          resumeDataStartup(ref),
        ];
        reminders.release.complete();
        await Future.wait(concurrent);
        await coordinator.startData(activate);
        await resumeDataStartup(ref);

        expect(activations, 1);
        expect(reminders.calls, 1);
        expect(database.sceneMigrations, 1);
        expect(autoSync.starts, 1);
        expect(queue.starts, 1);
        expect(container.read(migrationGateProvider).canEnterHome, isTrue);
        expect(MoodiaryKVs.syncPendingLocal.get(), dirty);
        expect(MoodiaryKVs.pendingMoodNotice.get(), notice);
      },
    );
  }
}
