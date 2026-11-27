import 'package:moodiary_data/moodiary_data.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/incremental_engine.dart';
import '../data/model/manifest.dart';
import '../data/model/sync_event.dart';
import '../data/sync.dart';
import '../data/sync_data_providers.dart';
import 'sync_operation_guard.dart';
import 'sync_runner.dart';

part 'sync_controller.g.dart';

@Riverpod(keepAlive: true)
class SyncController extends _$SyncController {
  @override
  SyncStatus build() => const SyncStatus();

  late final _runner = SyncRunner((backend, token, trigger) {
    final stores = ref.read(syncArchiveStoresProvider);
    return IncrementalSyncEngine(
      backend,
      trigger: trigger,
      cancellation: token,
      diaryStore: stores.diaries,
      categoryStore: stores.categories,
      tagStore: stores.tags,
      placeStore: stores.places,
      tombstoneStore: stores.tombstones,
      logger: ref.read(syncLoggerProvider),
      openDiaries: ref.read(openDiaryRegistryProvider),
      pending: ref.read(syncPendingStateProvider.notifier),
      dirty: ref.read(syncDirtyDiaryIdsProvider.notifier),
      configuredBackends: () =>
          ref.read(configuredCloudBackendIdsProvider.future),
    );
  });

  Future<SyncOutcome?> push() => _manual(.push);
  Future<SyncOutcome?> pull() => _manual(.pull);
  Future<SyncOutcome?> sync({
    Future<bool> Function(SyncOperation, IRemoteSyncBackend)? prepare,
  }) => _manual(.sync, prepare: prepare);

  Future<SyncOutcome?> _manual(
    SyncDirection direction, {
    Future<bool> Function(SyncOperation, IRemoteSyncBackend)? prepare,
  }) => ref.read(syncOperationGuardProvider).tryWithOperation<SyncOutcome?>((
    operation,
  ) async {
    final backend = ref.read(activeSyncBackendProvider);
    try {
      if (prepare != null && !await prepare(operation, backend)) return null;
    } on SyncException catch (error) {
      if (error.kind.affectsHealth) _applyFailure(error.kind, error.message);
      rethrow;
    }
    return run(operation, backend, direction, .manual);
  });

  Future<SyncOutcome> run(
    SyncOperation operation,
    IRemoteSyncBackend backend,
    SyncDirection direction,
    SyncTrigger trigger,
  ) async {
    operation.checkActive(ref.read(syncOperationGuardProvider));
    final result = _runner.run(backend, direction, trigger);
    state = state.copyWith(
      running: SyncActivity(
        trigger: trigger,
        direction: direction,
        backendName: backend.displayName,
        startedAt: DateTime.now(),
      ),
    );
    SyncOutcome? outcome;
    try {
      outcome = await result;
      final error = outcome.error;
      if (error == null) {
        _setHealth(.reachable);
      } else if (error.kind.affectsHealth) {
        _applyFailure(error.kind, error.message);
      }
      return outcome;
    } finally {
      state = state.copyWith(
        clearRunning: true,
        last: outcome == null
            ? null
            : (outcome: outcome, bannerDismissed: false),
        stopping: false,
      );
    }
  }

  Future<String?> probe(
    SyncOperation operation,
    IRemoteSyncBackend backend,
  ) async {
    operation.checkActive(ref.read(syncOperationGuardProvider));
    try {
      final stat = await backend.statObject(SyncKeys.manifestPath);
      _setHealth(.reachable);
      return stat;
    } on SyncException catch (error) {
      _applyFailure(error.kind, error.message, force: true);
      rethrow;
    }
  }

  Future<bool> testConnection() async =>
      await ref.read(syncOperationGuardProvider).tryRun(() async {
        final backend = ref.read(activeSyncBackendProvider);
        try {
          await backend.testConnection();
          _setHealth(.reachable);
          return true;
        } on SyncException catch (error) {
          _applyFailure(error.kind, error.message, force: true);
          rethrow;
        }
      }) ??
      false;

  void stop() {
    if (_runner.stop()) state = state.copyWith(stopping: true);
  }

  void dismissBanner() {
    final last = state.last;
    if (last != null && !last.bannerDismissed) {
      state = state.copyWith(
        last: (outcome: last.outcome, bannerDismissed: true),
      );
    }
  }

  void resetHealth() => state = state.copyWith(
    health: .unknown,
    healthSince: DateTime.now(),
    clearHealthDetail: true,
  );

  void markUnreachable() {
    if (state.health != .unreachable) _setHealth(.unreachable);
  }

  void _applyFailure(SyncErrorKind kind, String detail, {bool force = false}) {
    final health = switch (kind) {
      .auth => SyncHealth.authFailed,
      .keyConflict => SyncHealth.keyConflict,
      .notConfigured => SyncHealth.notConfigured,
      .network || .server || .http => SyncHealth.unreachable,
      _ => force ? SyncHealth.unreachable : null,
    };
    if (health == null) return;
    _setHealth(health, detail: SyncErrorKind.stripTag(detail));
  }

  void _setHealth(SyncHealth health, {String? detail}) {
    final current = state;
    final changed = current.health != health;
    if (changed) {
      if (health.isBad) {
        ref
            .read(syncLoggerProvider)
            .warn(
              .manifestRead,
              reason: .probeFailed,
              payload: {'health': health.name, 'detail': ?detail},
            );
      } else if (health == .reachable && current.health.isBad) {
        ref.read(syncLoggerProvider).info(.manifestRead, reason: .recovered);
      }
    }
    state = current.copyWith(
      health: health,
      healthSince: changed ? DateTime.now() : null,
      healthDetail: detail,
      clearHealthDetail: detail == null && changed,
    );
  }
}
