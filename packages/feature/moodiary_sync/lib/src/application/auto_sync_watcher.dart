import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_sync/src/application/sync_runner.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_data_providers.dart';
import 'package:moodiary_sync/src/data/sync_key_manager.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'sync_controller.dart';
import 'sync_operation_guard.dart';

part 'auto_sync_watcher.g.dart';

@Riverpod(keepAlive: true)
DateTime? autoSyncNextPollAt(Ref ref) {
  final watcher = ref.watch(autoSyncWatcherProvider);
  final subscription = watcher._scheduleChanges.stream.listen(
    (_) => ref.invalidateSelf(),
  );
  ref.onDispose(() => unawaited(subscription.cancel()));
  return watcher.nextPollAt;
}

@Riverpod(keepAlive: true)
AutoSyncWatcher autoSyncWatcher(Ref ref) {
  final watcher = AutoSyncWatcher(
    ref.watch(syncOperationGuardProvider),
    ref.watch(syncControllerProvider.notifier),
    ref.watch(diaryRepositoryProvider),
    ref.watch(categoryRepositoryProvider),
    ref.watch(tagRepositoryProvider),
    ref.watch(placeRepositoryProvider),
    ref.watch(syncDirtyDiaryIdsProvider.notifier),
    ref.watch(openDiaryRegistryProvider),
    resolveBackend: () => ref.read(activeSyncBackendProvider),
    configuredBackends: () =>
        ref.read(configuredCloudBackendIdsProvider.future),
    isDirty: (id) => ref.read(syncDirtyDiaryIdsProvider).contains(id),
  );
  ref.onDispose(() => unawaited(watcher.dispose()));
  return watcher;
}

class AutoSyncWatcher {
  AutoSyncWatcher(
    this._guard,
    this._controller,
    this._diaries,
    this._categories,
    this._tags,
    this._places,
    this._dirty,
    this._openDiaries, {
    required this.resolveBackend,
    required this.configuredBackends,
    required this._isDirty,
    Stream<bool> Function() onlineChanges = _onlineChanges,
  }) : _networkChanges = onlineChanges;

  final SyncOperationGuard _guard;
  final SyncController _controller;
  final bool Function(String) _isDirty;
  final _scheduleChanges = StreamController<void>.broadcast();
  DateTime? _nextPollAt;
  DateTime? get nextPollAt => _nextPollAt;
  static Stream<bool> _onlineChanges() => NetworkStatus.onlineChanges;
  final IRemoteSyncBackend Function() resolveBackend;
  final Future<Set<String>> Function() configuredBackends;
  final Stream<bool> Function() _networkChanges;

  final DiaryRepository _diaries;
  final CategoryRepository _categories;
  final TagRepository _tags;
  final PlaceRepository _places;
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
  StreamSubscription<TagEvent>? _tagSub;
  StreamSubscription<PlaceEvent>? _placeSub;
  StreamSubscription<String>? _closedSub;
  StreamSubscription<bool>? _guardSub;
  StreamSubscription<bool>? _netSub;
  AppLifecycleListener? _lifecycle;

  int _probeFailStreak = 0;
  DateTime? _lastTickAt;

  Timer? _timer;

  DateTime? _timerDue;
  SyncTrigger _pendingTrigger = .change;
  Timer? _pollTimer;
  int _localVersion = 0;
  bool _retryAfterOperation = false;

  bool _started = false;

  void start() {
    if (_started || _scheduleChanges.isClosed) return;
    _started = true;
    _diarySub ??= _diaries.diaryEvents.listen((event) async {
      if (event.fromSync || !_started) return;
      _markLocalChange();
      switch (event) {
        case DiaryCreated(:final diary) || DiaryUpdated(:final diary):
          if ((await configuredBackends()).isNotEmpty && _started) {
            _dirty.markDirty(diary.id);
          }
          if (!_openDiaries.contains(diary.id)) _onLocalChange();
        case DiaryDeleted(:final id):
          _dirty.clearDirty(id);
          _onLocalChange();
      }
    });
    _categorySub ??= _categories.categoryEvents.listen((event) {
      if (event.fromSync || !_started) return;
      _markLocalChange();
      _onLocalChange();
    });
    _tagSub ??= _tags.tagEvents.listen((event) {
      if (event.fromSync || !_started) return;
      _markLocalChange();
      _onLocalChange();
    });
    _placeSub ??= _places.placeEvents.listen((event) {
      if (event.fromSync || !_started) return;
      _markLocalChange();
      _onLocalChange();
    });
    _closedSub ??= _openDiaries.closed.listen((id) {
      if (!_isDirty(id) && MoodiaryKVs.syncPendingLocal.get() != true) {
        return;
      }
      _onLocalChange(trigger: .close, delay: _closeDebounce);
    });
    _guardSub = _guard.changes.listen(_onGuardChanged);
    _netSub ??= _networkChanges().listen((online) {
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

  Future<void> dispose() async {
    if (_scheduleChanges.isClosed) return;
    _started = false;
    _nextPollAt = null;
    _scheduleChanges.add(null);
    final closed = _scheduleChanges.close();
    _timer?.cancel();
    _timer = null;
    _timerDue = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    await _guardSub?.cancel();
    _guardSub = null;
    MoodiaryKVs.syncPollInterval.getNotifier().removeListener(_schedulePoll);
    await _diarySub?.cancel();
    await _categorySub?.cancel();
    await _tagSub?.cancel();
    await _placeSub?.cancel();
    await _closedSub?.cancel();
    await _netSub?.cancel();
    _lifecycle?.dispose();
    _lifecycle = null;
    _diarySub = null;
    _categorySub = null;
    _tagSub = null;
    _placeSub = null;
    _closedSub = null;
    _netSub = null;
    await closed;
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
    _nextPollAt = DateTime.now().add(Duration(seconds: seconds));
    _scheduleChanges.add(null);
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

  void _markLocalChange() {
    _localVersion++;
    MoodiaryKVs.syncPendingLocal.set(true);
  }

  void _onLocalChange({
    SyncTrigger trigger = .change,
    Duration delay = _debounce,
  }) {
    if (MoodiaryKVs.autoSync.get() != true) return;
    if (!_started) return;
    if (_guard.isBusy) {
      _retryAfterOperation = true;
      return;
    }
    _scheduleDebounced(delay, trigger);
  }

  void _onGuardChanged(bool busy) {
    if (!busy && _retryAfterOperation && _started) {
      _retryAfterOperation = false;
      _scheduleDebounced(_debounce, .change);
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
    if (_guard.isBusy) {
      _retryAfterOperation = true;
      return;
    }
    await _guard.tryWithOperation((operation) async {
      final backend = resolveBackend();
      final version = _localVersion;
      if (await backend.isReady()) {
        await _runAutoSync(operation, backend, .push, trigger, version);
      }
    });
  }

  Future<void> _pollTick({SyncTrigger trigger = .poll}) async {
    if (MoodiaryKVs.autoSync.get() != true) return;
    await _guard.tryWithOperation((operation) async {
      final backend = resolveBackend();
      final version = _localVersion;
      if (!await backend.isReady()) return;
      _lastTickAt = DateTime.now();

      String? preStat;
      final backendId = backend.persistentBackendId;
      if (backendId != null) {
        try {
          final stat = await _controller.probe(operation, backend);
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
        operation,
        backend,
        .sync,
        trigger,
        version,
        onSuccess: preStat == null
            ? null
            : () => MoodiaryKVs.syncManifestStat.set(preStat!),
      );
    });
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
    SyncOperation operation,
    IRemoteSyncBackend backend,
    SyncDirection direction,
    SyncTrigger trigger,
    int version, {
    void Function()? onSuccess,
  }) async {
    if (!_started ||
        SyncKeyManager.hasKeyConflict(backend.persistentBackendId)) {
      return;
    }
    final outcome = await _controller.run(
      operation,
      backend,
      direction,
      trigger,
    );
    final report = outcome.report;
    if (report != null && report.failed == 0 && !report.cancelled) {
      if (clearsPendingLocal(
        report,
        dirtyDuringSync: version != _localVersion,
      )) {
        MoodiaryKVs.syncPendingLocal.set(false);
      }
      onSuccess?.call();
    }
  }
}
