import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart'
    show ValueListenable, ValueNotifier, visibleForTesting;
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:injectable/injectable.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_sync/src/application/sync_runner.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_key_manager.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';
import 'package:moodiary_sync/src/data/sync_provider_scope.dart';

@lazySingleton
class AutoSyncWatcher {
  AutoSyncWatcher(
    this._logger,
    this._runner,
    this._diaries,
    this._categories,
    this._places,
    this._mediaInfos,
    this._dirty,
    this._openDiaries,
  );

  final SyncLogger _logger;
  final SyncRunner _runner;
  final DiaryRepository _diaries;
  final CategoryRepository _categories;
  final PlaceRepository _places;
  final MediaInfoRepository _mediaInfos;
  final SyncDirtyTracker _dirty;
  final OpenDiaryRegistry _openDiaries;

  static const Duration _debounce = Duration(seconds: 5);

  static const Duration _closeDebounce = Duration(milliseconds: 1500);

  static const int _minPollSeconds = 5;

  static const int _defaultPollSeconds = 30;

  static const int _maxBackoffSeconds = 600;

  static const Duration _resumeMinGap = Duration(seconds: 10);

  StreamSubscription<DiaryEvent>? _diarySub;
  StreamSubscription<CategoryEvent>? _categorySub;
  StreamSubscription<PlaceEvent>? _placeSub;
  StreamSubscription<MediaInfoEvent>? _mediaInfoSub;
  StreamSubscription<String>? _closedSub;
  StreamSubscription<SyncEvent>? _syncSub;
  StreamSubscription<bool>? _netSub;
  AppLifecycleListener? _lifecycle;

  int _probeFailStreak = 0;
  DateTime? _lastTickAt;

  final ValueNotifier<DateTime?> _nextPollAt = ValueNotifier(null);

  ValueListenable<DateTime?> get nextPollAt => _nextPollAt;

  Timer? _timer;

  DateTime? _timerDue;
  SyncTrigger _pendingTrigger = .change;
  Timer? _pollTimer;
  bool _syncing = false;
  bool _dirtyDuringSync = false;

  bool _started = false;

  void start() {
    _started = true;
    _diarySub ??= _diaries.diaryEvents.listen((event) async {
      if (event.fromSync) return;
      MoodiaryKVs.syncPendingLocal.set(true);
      switch (event) {
        case DiaryCreated(:final diary) || DiaryUpdated(:final diary):
          if ((await configuredCloudBackendIds()).isNotEmpty) {
            _dirty.markDirty(diary.id);
          }
          if (!_openDiaries.contains(diary.id)) _onLocalChange();
        case DiaryDeleted(:final id):
          _dirty.clearDirty(id);
          _onLocalChange();
      }
    });
    _categorySub ??= _categories.categoryEvents.listen((event) {
      if (event.fromSync) return;
      MoodiaryKVs.syncPendingLocal.set(true);
      _onLocalChange();
    });
    _placeSub ??= _places.placeEvents.listen((event) {
      if (event.fromSync) return;
      MoodiaryKVs.syncPendingLocal.set(true);
      _onLocalChange();
    });
    _mediaInfoSub ??= _mediaInfos.mediaInfoEvents.listen((event) {
      if (event.fromSync) return;
      MoodiaryKVs.syncPendingLocal.set(true);
      _onLocalChange();
    });
    _closedSub ??= _openDiaries.closed.listen((id) {
      if (!_dirty.listenable.value.contains(id) &&
          MoodiaryKVs.syncPendingLocal.get() != true) {
        return;
      }
      _onLocalChange(trigger: .close, delay: _closeDebounce);
    });
    _syncSub ??= _logger.events.listen(_onSyncEvent);
    _netSub ??= NetworkStatus.onlineChanges.listen((online) {
      if (online) _kick(.network);
    }, onError: (_) {});
    _lifecycle ??= AppLifecycleListener(onResume: _onResume, onHide: _onHide);
    MoodiaryKVs.syncPollInterval.getNotifier().addListener(_schedulePoll);
    _schedulePoll();
  }

  void _onResume() {
    final last = _lastTickAt;
    if (last != null && DateTime.now().difference(last) < _resumeMinGap) {
      return;
    }
    _kick(.resume);
  }

  void _onHide() {
    if (_timer == null) return;
    _timer!.cancel();
    _timer = null;
    _timerDue = null;
    unawaited(_trigger());
  }

  void _kick(SyncTrigger trigger) {
    if (!_started) return;
    _probeFailStreak = 0;
    _schedulePoll();
    unawaited(_pollTick(trigger: trigger));
  }

  @disposeMethod
  Future<void> dispose() async {
    _started = false;
    _timer?.cancel();
    _timer = null;
    _timerDue = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _nextPollAt.value = null;
    MoodiaryKVs.syncPollInterval.getNotifier().removeListener(_schedulePoll);
    await _diarySub?.cancel();
    await _categorySub?.cancel();
    await _placeSub?.cancel();
    await _mediaInfoSub?.cancel();
    await _closedSub?.cancel();
    await _syncSub?.cancel();
    await _netSub?.cancel();
    _lifecycle?.dispose();
    _lifecycle = null;
    _diarySub = null;
    _categorySub = null;
    _placeSub = null;
    _mediaInfoSub = null;
    _closedSub = null;
    _syncSub = null;
    _netSub = null;
  }

  static int _resolvePollSeconds() {
    final raw = MoodiaryKVs.syncPollInterval.get() ?? _defaultPollSeconds;
    return raw < _minPollSeconds ? _minPollSeconds : raw;
  }

  void _schedulePoll() {
    if (!_started) return;
    _pollTimer?.cancel();
    final seconds = pollDelaySeconds(
      base: _resolvePollSeconds(),
      failStreak: _probeFailStreak,
    );
    _nextPollAt.value = DateTime.now().add(Duration(seconds: seconds));
    _pollTimer = Timer(Duration(seconds: seconds), () async {
      await _pollTick();
      if (_started) _schedulePoll();
    });
  }

  @visibleForTesting
  static bool clearsPendingLocal(
    SyncReport report, {
    required bool dirtyDuringSync,
  }) => !dirtyDuringSync && report.skippedOpen == 0;

  @visibleForTesting
  static int pollDelaySeconds({required int base, required int failStreak}) {
    if (failStreak <= 0) return base;
    final shifted = base * (1 << min(failStreak, 10));
    return min(shifted, _maxBackoffSeconds);
  }

  void _onLocalChange({
    SyncTrigger trigger = .change,
    Duration delay = _debounce,
  }) {
    if (MoodiaryKVs.autoSync.get() != true) return;
    if (_syncing) {
      _dirtyDuringSync = true;
      return;
    }
    _scheduleDebounced(delay, trigger);
  }

  void _onSyncEvent(SyncEvent event) {
    switch (event.kind) {
      case .syncStart:
        _syncing = true;
        _timer?.cancel();
        _timer = null;
        _timerDue = null;
      case .syncEnd:
        _syncing = false;
        if (_dirtyDuringSync) {
          _dirtyDuringSync = false;
          _scheduleDebounced(_debounce, .change);
        }
      default:
        break;
    }
  }

  void _scheduleDebounced(Duration delay, SyncTrigger trigger) {
    final due = DateTime.now().add(delay);
    if (_timer != null && !shouldRearm(currentDue: _timerDue, newDue: due)) {
      return;
    }
    _timer?.cancel();
    _timerDue = due;
    _pendingTrigger = trigger;
    _timer = Timer(delay, _trigger);
  }

  @visibleForTesting
  static bool shouldRearm({
    required DateTime? currentDue,
    required DateTime newDue,
  }) => currentDue == null || newDue.isBefore(currentDue);

  Future<void> _trigger() async {
    _timer = null;
    _timerDue = null;
    final trigger = _pendingTrigger;
    if (MoodiaryKVs.autoSync.get() != true) return;
    await _runAutoSync(.push, trigger);
  }

  Future<void> _pollTick({SyncTrigger trigger = .poll}) async {
    if (MoodiaryKVs.autoSync.get() != true) return;
    if (_syncing || _runner.isRunning) return;
    final backend = getIt.maybeGet<IRemoteSyncBackend>();
    if (backend == null) return;
    if (!await backend.isReady()) return;
    _lastTickAt = DateTime.now();

    String? preStat;
    final backendId = backend.persistentBackendId;
    if (backendId != null) {
      try {
        final stat = await _runner.probe(trigger: trigger);
        // 格式固定为 'id|串'，改了会导致老用户缓存的 stat 全部失配
        preStat = '$backendId|${stat ?? ''}';
      } catch (_) {
        _probeFailStreak++;
        return;
      }
      _probeFailStreak = 0;
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
      .sync,
      trigger,
      onSuccess: preStat == null
          ? null
          : () => MoodiaryKVs.syncManifestStat.set(preStat!),
    );
  }

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

  Future<void> _runAutoSync(
    SyncDirection direction,
    SyncTrigger trigger, {
    void Function()? onSuccess,
  }) async {
    if (_syncing || _runner.isRunning) return;
    final backend = getIt.maybeGet<IRemoteSyncBackend>();
    if (backend == null) return;
    if (!await backend.isReady()) return;
    if (SyncKeyManager.hasKeyConflict(backend.persistentBackendId)) return;

    _syncing = true;
    try {
      final outcome = await _runner.run(direction, trigger: trigger);
      final report = outcome?.report;
      if (report != null && report.failed == 0 && !report.cancelled) {
        if (clearsPendingLocal(report, dirtyDuringSync: _dirtyDuringSync)) {
          MoodiaryKVs.syncPendingLocal.set(false);
        }
        onSuccess?.call();
      }
    } finally {
      _syncing = false;
      if (_dirtyDuringSync) {
        _dirtyDuringSync = false;
        _scheduleDebounced(_debounce, .change);
      }
    }
  }
}
