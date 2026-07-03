import 'dart:async';

import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';

/// 自动同步监听器 —— 单开关 [MoodiaryKVs.autoSync] 启用两条机制，共用「正在同步」
/// 闸门（[_syncing]）：变更触发（订阅领域事件流，去抖后 pushAll）+ 周期轮询
/// （每 [MoodiaryKVs.syncPollInterval] 秒双向 syncAll）。
///
/// 设计要点：
/// - **数据源**：订阅 [DiaryRepository.diaryEvents] / [CategoryRepository.categoryEvents]
///   而非 Isar `watchLazy` —— 领域流只在写成功后发出（零误报），且引擎内部走 `merge`
///   等旁路写入不进领域流，天然避免 pull → push 回环。
/// - **互斥**：监听 [SyncLogger.events] 的 `syncStart`/`syncEnd`，任何 push/pull 进行中
///   都暂停响应，故 sync 内部写入（如 tombstone 清理）不会引发二次同步。
/// - **静默失败**：出错不弹 toast，错误已落进 SyncLogger。
class AutoSyncWatcher {
  AutoSyncWatcher._();

  static AutoSyncWatcher create() => AutoSyncWatcher._();

  factory AutoSyncWatcher.get() => getIt<AutoSyncWatcher>();

  /// 写入后到真正发起 push 的静默期。
  static const Duration _debounce = Duration(seconds: 5);

  /// 轮询间隔下限（秒）。塞更小值也夹到此 —— 过频轮询每次抢锁 + 读清单，徒增流量/耗电。
  static const int _minPollSeconds = 5;

  /// 轮询间隔缺省值（秒），与 [MoodiaryKVs.syncPollInterval] 的 defaultValue 一致。
  static const int _defaultPollSeconds = 30;

  StreamSubscription<DiaryEvent>? _diarySub;
  StreamSubscription<CategoryEvent>? _categorySub;
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
      switch (event) {
        case DiaryCreated(:final diary) || DiaryUpdated(:final diary):
          // 本地有改动 → 标记卡片「待同步」（软删 / tombstone 不标，将离开列表）。
          if (!diary.deleted) SyncDirtyTracker.instance.markDirty(diary.id);
          // 打开中的日记不触发同步（编辑期不上传半成品）。这是廉价前置闸门；权威跳过
          // 在引擎 push 快照里（poll / syncAll 绕过本闸门）。
          if (!OpenDiaryRegistry.instance.contains(diary.id)) _onLocalChange();
        case DiaryDeleted():
          // 只带 isarId、无业务 id：放行触发同步（删除应尽快同步）。
          _onLocalChange();
      }
    });
    _categorySub ??= CategoryRepository.get().categoryEvents.listen(
      (_) => _onLocalChange(),
    );
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
    await _syncSub?.cancel();
    _diarySub = null;
    _categorySub = null;
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
      case SyncEventKind.syncStart:
        _syncing = true;
        // 已有同步在跑，撤掉待发 push；同步内部写入由 _dirtyDuringSync 兜底。
        _timer?.cancel();
        _timer = null;
      case SyncEventKind.syncEnd:
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

  /// 周期轮询到点：双向 sync。开关关闭时读 KV 直接空转返回。
  Future<void> _pollTick() async {
    if (MoodiaryKVs.autoSync.get() != true) return;
    await _runAutoSync((backend) => backend.syncAll());
  }

  /// 公共执行体：复查同步状态/后端就绪后跑 [op]，失败静默吞。结束后若同步期间有
  /// 新变更（[_dirtyDuringSync]）则补排一次去抖 push。
  Future<void> _runAutoSync(
    Future<SyncReport> Function(IRemoteSyncBackend) op,
  ) async {
    if (_syncing) return;
    if (!getIt.isRegistered<IRemoteSyncBackend>()) return;
    final backend = IRemoteSyncBackend.get();
    if (!backend.isReady) return;

    _syncing = true;
    try {
      await op(backend);
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
