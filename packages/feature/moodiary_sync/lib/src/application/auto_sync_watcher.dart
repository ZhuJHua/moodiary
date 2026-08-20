import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';
import 'package:moodiary_sync/src/data/sync_registry.dart';

/// 自动同步监听器 —— 单开关 [MoodiaryKVs.autoSync] 启用两条机制，共用「正在同步」
/// 闸门（[_syncing]）：变更触发（订阅领域事件流，去抖后 pushAll）+ 周期轮询
/// （每 [MoodiaryKVs.syncPollInterval] 秒双向 syncAll）。
///
/// 设计要点：
/// - **数据源**：订阅 [DiaryRepository.diaryEvents] / [CategoryRepository.categoryEvents]
///   而非 Isar `watchLazy` —— 领域流只在写成功后发出（零误报）。云 pull 落库的
///   事件带 `fromSync` 标记，据此不标脏、不回声推送（远端已持有）；归档导入 /
///   局域网接收不带标记，照常触发向云端的推送。
/// - **互斥**：监听 [SyncLogger.events] 的 `syncStart`/`syncEnd`，任何 push/pull 进行中
///   都暂停响应，故 sync 内部写入（如 tombstone 清理）不会引发二次同步。
/// - **空转短路**：轮询先 HEAD 远端 manifest（[MoodiaryKVs.syncManifestStat] 缓存
///   指纹），未变且本地无待推变更（[MoodiaryKVs.syncPendingLocal]）→ 跳过整个
///   syncAll，把空转成本从 5 个往返降到 1 个 HEAD。Last-Modified 是秒级粒度，
///   同秒并发写理论上可漏判，故距上次成功同步超过 10 个轮询周期时强制全量兜底。
/// - **静默失败**：出错不弹 toast，错误已落进 SyncLogger。
class AutoSyncWatcher {
  AutoSyncWatcher._();

  static AutoSyncWatcher create() => ._();

  factory AutoSyncWatcher.get() => getIt<AutoSyncWatcher>();

  /// 写入后到真正发起 push 的静默期。
  static const Duration _debounce = Duration(seconds: 5);

  /// 轮询间隔下限（秒）。塞更小值也夹到此 —— 过频轮询每次抢锁 + 读清单，徒增流量/耗电。
  static const int _minPollSeconds = 5;

  /// 轮询间隔缺省值（秒），与 [MoodiaryKVs.syncPollInterval] 的 defaultValue 一致。
  static const int _defaultPollSeconds = 30;

  StreamSubscription<DiaryEvent>? _diarySub;
  StreamSubscription<CategoryEvent>? _categorySub;
  StreamSubscription<MediaInfoEvent>? _mediaInfoSub;
  StreamSubscription<SyncEvent>? _syncSub;

  Timer? _timer;
  Timer? _pollTimer;
  bool _syncing = false;
  bool _dirtyDuringSync = false;

  /// 监听器是否在生命周期内 —— 自调度轮询据此决定 tick 后是否续期，避免 [dispose]
  /// 在一次 tick 进行中时被随后的续期重新拉起。
  bool _started = false;

  void start() {
    _started = true;
    _diarySub ??= DiaryRepository.get().diaryEvents.listen((event) {
      // 云 pull 落库的变更远端已持有：不标脏、不置待推标记、不排推送。
      if (event.fromSync) return;
      MoodiaryKVs.syncPendingLocal.set(true);
      switch (event) {
        case DiaryCreated(:final diary) || DiaryUpdated(:final diary):
          // 本地有改动 → 标记卡片「待同步」。
          // 仅在配置了云后端时才追踪：没配同步就没有「待同步」概念，避免误导角标。
          if (configuredCloudBackendIds().isNotEmpty) {
            SyncDirtyTracker.instance.markDirty(diary.id);
          }
          // 打开中的日记不触发同步（编辑期不上传半成品）。这是廉价前置闸门；权威跳过
          // 在引擎 push 快照里（poll / syncAll 绕过本闸门）。
          if (!OpenDiaryRegistry.instance.contains(diary.id)) _onLocalChange();
        case DiaryDeleted():
          // 只带 isarId、无业务 id：放行触发同步（永久删除的墓碑应尽快推送）。
          _onLocalChange();
      }
    });
    _categorySub ??= CategoryRepository.get().categoryEvents.listen((event) {
      if (event.fromSync) return;
      MoodiaryKVs.syncPendingLocal.set(true);
      _onLocalChange();
    });
    _mediaInfoSub ??= MediaInfoRepository.get().mediaInfoEvents.listen((event) {
      if (event.fromSync) return;
      MoodiaryKVs.syncPendingLocal.set(true);
      _onLocalChange();
    });
    _syncSub ??= SyncLogger.get().events.listen(_onSyncEvent);
    // 改了轮询间隔 → 立即按新值重排（缩短间隔不必等旧定时器走完）。
    MoodiaryKVs.syncPollInterval.getNotifier().addListener(_schedulePoll);
    _schedulePoll();
  }

  Future<void> dispose() async {
    _started = false;
    _timer?.cancel();
    _timer = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    MoodiaryKVs.syncPollInterval.getNotifier().removeListener(_schedulePoll);
    await _diarySub?.cancel();
    await _categorySub?.cancel();
    await _mediaInfoSub?.cancel();
    await _syncSub?.cancel();
    _diarySub = null;
    _categorySub = null;
    _mediaInfoSub = null;
    _syncSub = null;
  }

  static int _resolvePollSeconds() {
    final raw = MoodiaryKVs.syncPollInterval.get() ?? _defaultPollSeconds;
    return raw < _minPollSeconds ? _minPollSeconds : raw;
  }

  /// 自调度轮询：单次定时器到点跑 [_pollTick]，跑完按当前 KV 间隔续期。比
  /// `Timer.periodic` 好在：间隔可热更新，且续期在上一 tick 完成后、长同步不与
  /// 下一 tick 叠加。开关关闭时定时器照转，但 [_pollTick] 读 KV 直接空转返回。
  void _schedulePoll() {
    if (!_started) return;
    _pollTimer?.cancel();
    _pollTimer = Timer(Duration(seconds: _resolvePollSeconds()), () async {
      await _pollTick();
      if (_started) _schedulePoll();
    });
  }

  void _onLocalChange() {
    if (MoodiaryKVs.autoSync.get() != true) return;
    if (_syncing) {
      // 同步进行中的写入：记脏标，等同步结束再合并触发。
      _dirtyDuringSync = true;
      return;
    }
    _scheduleDebounced();
  }

  void _onSyncEvent(SyncEvent event) {
    switch (event.kind) {
      case .syncStart:
        _syncing = true;
        // 已有同步在跑，撤掉待发 push；同步内部写入由 _dirtyDuringSync 兜底。
        _timer?.cancel();
        _timer = null;
      case .syncEnd:
        _syncing = false;
        if (_dirtyDuringSync) {
          _dirtyDuringSync = false;
          _scheduleDebounced();
        }
      default:
        break;
    }
  }

  void _scheduleDebounced() {
    _timer?.cancel();
    _timer = Timer(_debounce, _trigger);
  }

  /// 变更去抖到点：只 push 本地改动（pull 由周期轮询负责）。
  Future<void> _trigger() async {
    _timer = null;
    if (MoodiaryKVs.autoSync.get() != true) return;
    await _runAutoSync((backend) => backend.pushAll());
  }

  /// 周期轮询到点：先做空转短路探测，未命中才双向 sync。开关关闭时直接空转返回。
  Future<void> _pollTick() async {
    if (MoodiaryKVs.autoSync.get() != true) return;
    if (_syncing) return;
    if (!getIt.isRegistered<IRemoteSyncBackend>()) return;
    final backend = IRemoteSyncBackend.get();
    if (!backend.isReady) return;

    String? preStat;
    final backendId = backend.persistentBackendId;
    if (backendId != null) {
      try {
        final stat = await backend.statObject(SyncKeys.manifestPath);
        preStat = '$backendId|$stat';
      } catch (_) {
        // 远端不可达：完整同步同样会失败，静默等下个周期（省掉整套租约往返）。
        return;
      }
      if (shouldSkipPoll(
        preStat: preStat,
        cachedStat: MoodiaryKVs.syncManifestStat.get(),
        pendingLocal: MoodiaryKVs.syncPendingLocal.get() ?? true,
        lastSyncMs: MoodiaryKVs.lastSyncTime.get() ?? 0,
        nowMs: DateTime.now().millisecondsSinceEpoch,
        pollSeconds: _resolvePollSeconds(),
      )) {
        return;
      }
    }
    await _runAutoSync(
      (backend) => backend.syncAll(),
      // 缓存的是同步开始前观测的指纹：本机 push 会再改 manifest，使下一轮指纹
      // 不匹配、多跑一次（随即空转的）全量同步 —— 换取「同步期间他机写入必不被
      // 漏判」。
      onSuccess: preStat == null
          ? null
          : () => MoodiaryKVs.syncManifestStat.set(preStat!),
    );
  }

  /// 空转短路判定（纯函数，便于单测）：远端指纹未变 + 本地无待推变更 + 距上次
  /// 成功同步不超过兜底窗（10 个轮询周期，上限 30 分钟）。兜底窗保证秒级粒度
  /// 漏判与「待推标记未落盘就被杀进程」都能在有限时间内收敛，且不随用户把
  /// 轮询间隔调大而无限放大。
  @visibleForTesting
  static bool shouldSkipPoll({
    required String preStat,
    required String? cachedStat,
    required bool pendingLocal,
    required int lastSyncMs,
    required int nowMs,
    required int pollSeconds,
  }) {
    if (pendingLocal) return false;
    if (preStat != cachedStat) return false;
    if (lastSyncMs <= 0) return false;
    final beltMs = min(pollSeconds * 10, 1800) * 1000;
    return nowMs - lastSyncMs <= beltMs;
  }

  /// 公共执行体：复查同步状态/后端就绪后跑 [op]，失败静默吞。结束后若同步期间有
  /// 新变更（[_dirtyDuringSync]）则补排一次去抖 push。成功（零失败未取消）时清
  /// 待推标记并执行 [onSuccess]；同步期间的新变更由 [_dirtyDuringSync] 兜底，
  /// 不清标记。
  Future<void> _runAutoSync(
    Future<SyncReport> Function(IRemoteSyncBackend) op, {
    void Function()? onSuccess,
  }) async {
    if (_syncing) return;
    if (!getIt.isRegistered<IRemoteSyncBackend>()) return;
    final backend = IRemoteSyncBackend.get();
    if (!backend.isReady) return;

    _syncing = true;
    try {
      final report = await op(backend);
      if (report.failed == 0 && !report.cancelled) {
        if (!_dirtyDuringSync) {
          MoodiaryKVs.syncPendingLocal.set(false);
        }
        onSuccess?.call();
      }
    } catch (e, st) {
      logger.e('auto-sync failed', error: e, stackTrace: st);
    } finally {
      _syncing = false;
      if (_dirtyDuringSync) {
        _dirtyDuringSync = false;
        _scheduleDebounced();
      }
    }
  }
}
