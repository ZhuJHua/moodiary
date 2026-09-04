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

/// 远端连接健康。由每次同步 / 轮询探测 / 测试连接的结果更新，UI 据此给
/// 「无法连接」「凭据失效」这类需要用户动手的提示。
enum SyncHealth {
  unknown,
  notConfigured,
  reachable,
  unreachable,
  authFailed,
  keyConflict;

  /// 需要用户去做点什么的状态。
  bool get isBad => switch (this) {
    .unreachable || .authFailed || .keyConflict => true,
    _ => false,
  };
}

enum SyncOutcomeKind { upToDate, changed, partial, stopped, failed }

/// 正在跑的那一次。
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

/// 本进程内最近一次跑完的结果（手动与自动同源）。
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

  /// 给用户的一句话：报告摘要或错误文案。
  String get message => report?.userSummary() ?? error?.message ?? '';

  bool get ok => kind == .upToDate || kind == .changed;
}

class SyncStatus {
  /// null = 空闲。
  final SyncActivity? running;
  final SyncOutcome? last;
  final SyncHealth health;

  /// 进入当前健康态的时刻。
  final DateTime? healthSince;

  /// 最近一次失败的明细（已摘掉机器标签）。
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

/// 同步的唯一执行入口：手动、变更、关闭日记、轮询、回前台、网络恢复全经这里跑引擎，
/// 持有唯一一份「正在跑 / 上次结果 / 连接健康」（[status]）。UI 只看它，不再有
/// 「自动同步跑了但图标不转」这种两条路径各说各话的情况。
///
/// 不抛：[run] 把报告与错误都折进 [SyncOutcome]；[probe] / [testConnection] 抛出
/// 供调用方决定退避，但抛之前健康态已经更新。健康态的日志是**边沿触发**的：
/// 只在可达 ↔ 不可达切换时各记一条，轮询期间的重复失败不刷屏。
@singleton
class SyncRunner {
  SyncRunner(this._cancellation, this._logger)
    : _engineFactory = IncrementalSyncEngine.forCloud;

  /// 测试注入替身引擎（生产装配的引擎要碰 PlatformService 与真仓储）。
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

  /// 跑一次。已有同步在跑、或没有后端时返回 null（调用方各自的闸门通常已挡住，
  /// 这里是兜底）。
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
      // 跑到了引擎收尾就说明远端是通的，哪怕有条目失败。
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

  /// HEAD manifest；返回 stat 记号（null = 远端没有 manifest）。失败抛出供调用方
  /// 退避，健康态已更新——连清单都探不到，不论错误类别都算不可达。
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

  /// 设置页「测试连接」：结果同样写进健康态。
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

  /// 请求停止当前同步（协作式，见 [SyncCancellation]）。
  void stop() => _cancellation.requestStop();

  /// 后端换了配置：健康态回到未知，别拿旧服务器的结论说新服务器。
  void resetHealth() {
    _status.value = _status.value.copyWith(
      health: .unknown,
      healthSince: DateTime.now(),
      clearHealthDetail: true,
    );
  }

  /// [force]：探测 / 测试连接的失败一律影响健康态（连 HEAD 都失败没有「远端活着」
  /// 的余地）；同步运行中的失败只有 [SyncErrorKind.affectsHealth] 的那些才算。
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
