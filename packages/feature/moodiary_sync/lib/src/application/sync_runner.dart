import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_sync/src/data/incremental_engine.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_cancellation_token.dart';

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

typedef SyncLastRun = ({SyncOutcome outcome, bool bannerDismissed});

class SyncStatus {
  final SyncActivity? running;
  final SyncLastRun? last;
  final bool stopping;
  final SyncHealth health;

  final DateTime? healthSince;

  final String? healthDetail;

  const SyncStatus({
    this.running,
    this.stopping = false,
    this.last,
    this.health = .unknown,
    this.healthSince,
    this.healthDetail,
  });

  bool get isRunning => running != null;

  SyncStatus copyWith({
    SyncActivity? running,
    bool clearRunning = false,
    bool? stopping,
    SyncLastRun? last,
    SyncHealth? health,
    DateTime? healthSince,
    String? healthDetail,
    bool clearHealthDetail = false,
  }) => SyncStatus(
    running: clearRunning ? null : (running ?? this.running),
    last: last ?? this.last,
    stopping: stopping ?? this.stopping,
    health: health ?? this.health,
    healthSince: healthSince ?? this.healthSince,
    healthDetail: clearHealthDetail
        ? null
        : (healthDetail ?? this.healthDetail),
  );
}

class SyncRunner {
  SyncRunner(this._engineFactory);

  final IncrementalSyncEngine Function(
    IRemoteSyncBackend,
    SyncCancellationToken,
    SyncTrigger,
  )
  _engineFactory;
  SyncCancellationToken? _current;

  bool stop() {
    final token = _current;
    if (token == null || token.isRequested) return false;
    token.requestStop();
    return true;
  }

  Future<SyncOutcome> run(
    IRemoteSyncBackend backend,
    SyncDirection direction,
    SyncTrigger trigger,
  ) async {
    if (_current != null) throw StateError('Sync already running');
    final token = _current = SyncCancellationToken();
    final startedAt = DateTime.now();
    try {
      if (!await backend.isReady()) throw backend.notReadyError;
      final engine = _engineFactory(backend, token, trigger);
      final report = await switch (direction) {
        .push => engine.push(),
        .pull => engine.pull(),
        .sync => engine.sync(),
      };
      return SyncOutcome(
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
    } on SyncException catch (e) {
      return _failed(e, trigger, direction, startedAt);
    } catch (e, st) {
      logger.e('sync failed (${trigger.name})', error: e, stackTrace: st);
      return _failed(
        SyncException(e.toString()),
        trigger,
        direction,
        startedAt,
      );
    } finally {
      _current = null;
    }
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
}
