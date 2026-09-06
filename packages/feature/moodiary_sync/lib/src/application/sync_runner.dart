import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_sync/src/data/incremental_engine.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_cancellation.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';

enum SyncDirection { push, pull, sync }

enum SyncHealth {
  unknown,
  notConfigured,
  reachable,
  unreachable,
  authFailed,
  keyConflict;

  bool get isBad => switch (this) {
    .unreachable || .authFailed || .keyConflict => true,
    _ => false,
  };
}

enum SyncOutcomeKind { upToDate, changed, partial, stopped, failed }

class SyncActivity {
  final SyncTrigger trigger;
  final SyncDirection direction;
  final DateTime startedAt;
  final String backendName;

  const SyncActivity({
    required this.trigger,
    required this.direction,
    required this.startedAt,
    required this.backendName,
  });
}

class SyncOutcome {
  final DateTime at;
  final SyncTrigger trigger;
  final SyncDirection direction;
  final SyncOutcomeKind kind;
  final SyncReport? report;
  final SyncException? error;
  final Duration elapsed;

  const SyncOutcome({
    required this.at,
    required this.trigger,
    required this.direction,
    required this.kind,
    required this.elapsed,
    this.report,
    this.error,
  });

  String get message => report?.userSummary() ?? error?.message ?? '';

  bool get ok => kind == .upToDate || kind == .changed;
}

class SyncStatus {
  final SyncActivity? running;
  final SyncOutcome? last;
  final SyncHealth health;

  final DateTime? healthSince;

  final String? healthDetail;

  const SyncStatus({
    this.running,
    this.last,
    this.health = .unknown,
    this.healthSince,
    this.healthDetail,
  });

  bool get isRunning => running != null;

  SyncStatus copyWith({
    SyncActivity? running,
    bool clearRunning = false,
    SyncOutcome? last,
    SyncHealth? health,
    DateTime? healthSince,
    String? healthDetail,
    bool clearHealthDetail = false,
  }) => SyncStatus(
    running: clearRunning ? null : (running ?? this.running),
    last: last ?? this.last,
    health: health ?? this.health,
    healthSince: healthSince ?? this.healthSince,
    healthDetail: clearHealthDetail
        ? null
        : (healthDetail ?? this.healthDetail),
  );
}

@singleton
class SyncRunner {
  SyncRunner(this._cancellation, this._logger)
    : _engineFactory = IncrementalSyncEngine.forCloud;

  @visibleForTesting
  SyncRunner.withEngine(this._cancellation, this._logger, this._engineFactory);

  final SyncCancellation _cancellation;
  final SyncLogger _logger;
  final Future<IncrementalSyncEngine> Function(
    IRemoteSyncBackend backend, {
    SyncTrigger? trigger,
  })
  _engineFactory;

  final ValueNotifier<SyncStatus> _status = ValueNotifier(const SyncStatus());

  ValueListenable<SyncStatus> get status => _status;

  bool get isRunning => _status.value.isRunning;

  IRemoteSyncBackend? get _backend => getIt.maybeGet<IRemoteSyncBackend>();

  Future<SyncOutcome?> run(
    SyncDirection direction, {
    required SyncTrigger trigger,
  }) async {
    if (isRunning) return null;
    final backend = _backend;
    if (backend == null) return null;
    final startedAt = DateTime.now();
    _status.value = _status.value.copyWith(
      running: SyncActivity(
        trigger: trigger,
        direction: direction,
        startedAt: startedAt,
        backendName: backend.displayName,
      ),
    );
    late final SyncOutcome outcome;
    try {
      final engine = await _engineFactory(backend, trigger: trigger);
      final report = await switch (direction) {
        .push => engine.push(),
        .pull => engine.pull(),
        .sync => engine.sync(),
      };
      outcome = SyncOutcome(
        at: DateTime.now(),
        trigger: trigger,
        direction: direction,
        kind: report.cancelled
            ? .stopped
            : report.failed > 0
            ? .partial
            : report.changedNothing
            ? .upToDate
            : .changed,
        report: report,
        elapsed: report.elapsed,
      );
      _setHealth(.reachable);
    } on SyncException catch (e) {
      outcome = _failed(e, trigger, direction, startedAt);
      if (e.kind.affectsHealth) _applyFailure(e.kind, e.message);
    } catch (e, st) {
      logger.e('sync failed (${trigger.name})', error: e, stackTrace: st);
      outcome = _failed(
        SyncException(e.toString()),
        trigger,
        direction,
        startedAt,
      );
    } finally {
      _status.value = _status.value.copyWith(clearRunning: true, last: outcome);
    }
    return outcome;
  }

  SyncOutcome _failed(
    SyncException e,
    SyncTrigger trigger,
    SyncDirection direction,
    DateTime startedAt,
  ) => SyncOutcome(
    at: DateTime.now(),
    trigger: trigger,
    direction: direction,
    kind: .failed,
    error: e,
    elapsed: DateTime.now().difference(startedAt),
  );

  Future<String?> probe({required SyncTrigger trigger}) async {
    final backend = _backend;
    if (backend == null) {
      throw SyncException(l10n.sync.errNoBackend, kind: .notConfigured);
    }
    if (!await backend.isReady()) {
      _setHealth(.notConfigured);
      throw backend.notReadyError;
    }
    try {
      final stat = await backend.statObject(SyncKeys.manifestPath);
      _setHealth(.reachable);
      return stat;
    } on SyncException catch (e) {
      _applyFailure(e.kind, e.message, force: true);
      rethrow;
    }
  }

  Future<void> testConnection() async {
    final backend = _backend;
    if (backend == null) {
      throw SyncException(l10n.sync.errNoBackend, kind: .notConfigured);
    }
    try {
      await backend.testConnection();
      _setHealth(.reachable);
    } on SyncException catch (e) {
      _applyFailure(e.kind, e.message, force: true);
      rethrow;
    }
  }

  void stop() => _cancellation.requestStop();

  void resetHealth() {
    _status.value = _status.value.copyWith(
      health: .unknown,
      healthSince: DateTime.now(),
      clearHealthDetail: true,
    );
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
    final current = _status.value;
    final changed = current.health != health;
    if (changed) {
      if (health.isBad) {
        _logger.warn(
          .manifestRead,
          reason: .probeFailed,
          payload: {'health': health.name, 'detail': ?detail},
        );
      } else if (health == .reachable && current.health.isBad) {
        _logger.info(.manifestRead, reason: .recovered);
      }
    }
    _status.value = current.copyWith(
      health: health,
      healthSince: changed ? DateTime.now() : null,
      healthDetail: detail,
      clearHealthDetail: detail == null && changed,
    );
  }
}
