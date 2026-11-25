import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

import 'editor_migration_service.dart';
import 'legacy_database_guard.dart';
import 'version_migrator.dart';

class StartupMigrationCoordinator {
  Future<void>? _startup;

  bool _waitingForStartup = false;

  bool get canStartData =>
      LegacyDatabaseGuard.state == LegacyDatabaseState.none;
  bool get canEnterHome =>
      !_waitingForStartup &&
      canStartData &&
      !EditorMigrationService.requiresMigration;

  static Future<void> migrateVersion(IKVStorage storage) =>
      VersionMigrator.run(storage: storage);
  static Future<void> refreshEditorGate(DiaryRepository repository) =>
      EditorMigrationService.refreshRequiresMigration(repository: repository);

  Future<void> startData(Future<void> Function() resumeStartup) {
    if (!canStartData) {
      _waitingForStartup = true;
      return Future.value();
    }
    return _startup ??= _runStartup(resumeStartup);
  }

  Future<void> _runStartup(Future<void> Function() resumeStartup) async {
    _waitingForStartup = true;
    try {
      await Future.microtask(resumeStartup);
      _waitingForStartup = false;
    } catch (_) {
      _startup = null;
      rethrow;
    }
  }

  void completeEditorMigration() {
    EditorMigrationService.hasLegacyDiaries = false;
    EditorMigrationService.requiresContentUpgrade = false;
    EditorMigrationService.requiresMigration = false;
  }
}
