import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_migration/moodiary_migration.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';

class _Diaries extends Fake implements DiaryRepository {
  final diary = Diary.empty(type: .markdown);
  @override
  Future<bool> hasLegacyFormatDiaries() async => false;
  @override
  Future<int> countAllDiaries() async => 1;
  @override
  Future<List<Diary>> getAllDiaries() async => [diary];
  @override
  Future<int> upgradeContentSchema({
    void Function(int, int)? onProgress,
    int batchSize = 50,
  }) async => 1;
}

void main() {
  test(
    'content-only migration starts data once and unlocks home after upgrade',
    () async {
      final directory = Directory.systemTemp.createTempSync('content-upgrade');
      addTearDown(() => directory.delete(recursive: true));
      PlatformService.get().applicationSupportPath = directory.path;
      KVStore.installForTesting(MemoryKVStorage());
      addTearDown(KVStore.resetForTesting);
      MoodiaryKVs.dbEngineMigrated.set(true);
      final coordinator = StartupMigrationCoordinator();
      addTearDown(coordinator.completeEditorMigration);
      final repository = _Diaries();
      expect(await LegacyDatabaseGuard.probe(), LegacyDatabaseState.none);
      var starts = 0;
      Future<void> resume() async {
        starts++;
        await coordinator.refreshEditorGate(repository);
      }

      await Future.wait([
        coordinator.startData(resume),
        coordinator.startData(resume),
      ]);
      expect(coordinator.canStartData, isTrue);
      expect(coordinator.canEnterHome, isFalse);
      await EditorMigrationService.upgradeContent(repository: repository);
      coordinator.completeEditorMigration();
      expect(coordinator.canEnterHome, isTrue);
      expect(MoodiaryKVs.contentSchemaV2.get(), isTrue);
      expect(starts, 1);
    },
  );
}
