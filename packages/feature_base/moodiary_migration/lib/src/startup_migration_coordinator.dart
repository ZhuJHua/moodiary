import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

import 'editor_migration_service.dart';
import 'legacy_database_guard.dart';
import 'version_migrator.dart';

class StartupMigrationCoordinator {
  StartupMigrationCoordinator({this._onGateChanged});

  final void Function()? _onGateChanged;
  final Set<void Function()> _gateListeners = {};
  Future<void>? _startup;

  void addGateListener(void Function() listener) => _gateListeners.add(listener);

  void removeGateListener(void Function() listener) =>
      _gateListeners.remove(listener);

  void _notifyGateChanged() {
    _onGateChanged?.call();
    for (final listener in List<void Function()>.of(_gateListeners)) {
      listener();
    }
  }

  bool _waitingForStartup = true;

  bool get canStartData =>
      LegacyDatabaseGuard.state == LegacyDatabaseState.none;
  bool get canEnterHome =>
      !_waitingForStartup &&
      canStartData &&
      !EditorMigrationService.requiresMigration;

  static Future<void> migrateVersion(IKVStorage storage) =>
      VersionMigrator.run(storage: storage);

  Future<LegacyDatabaseState> probeLegacy() async {
    final state = await LegacyDatabaseGuard.probe();
    _notifyGateChanged();
    return state;
  }

  Future<void> abandonLegacy({
    required DiaryRepository diaries,
    required FontRepository fonts,
  }) async {
    try {
      await LegacyDatabaseGuard.abandon(diaries: diaries, fonts: fonts);
    } finally {
      _notifyGateChanged();
    }
  }

  Future<void> refreshEditorGate(DiaryRepository repository) async {
    await EditorMigrationService.refreshRequiresMigration(
      repository: repository,
    );
    _notifyGateChanged();
  }

  Future<void> startData(Future<void> Function() resumeStartup) {
    if (!canStartData) {
      _waitingForStartup = true;
      _notifyGateChanged();
      return Future.value();
    }
    return _startup ??= _runStartup(resumeStartup);
  }

  Future<void> _runStartup(Future<void> Function() resumeStartup) async {
    _waitingForStartup = true;
    _notifyGateChanged();
    try {
      await Future.microtask(resumeStartup);
      _waitingForStartup = false;
      _notifyGateChanged();
    } catch (_) {
      _startup = null;
      rethrow;
    }
  }

  void completeEditorMigration() {
    EditorMigrationService.hasLegacyDiaries = false;
    EditorMigrationService.requiresContentUpgrade = false;
    EditorMigrationService.requiresMigration = false;
    _notifyGateChanged();
  }
}
