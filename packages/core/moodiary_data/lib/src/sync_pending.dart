import 'package:flutter/foundation.dart';

/// pull 预扫描得出的「即将从远端到达」清单。引擎读完 manifest 后用快照 LWW 一次
/// 算出，首页据此**立即**渲染占位卡/角标，不必等每条落库；逐条下载完成时消除。
/// 占位只是 UI 预告，最终以逐条阶段「写入前重读」的精确 LWW 落库事件为准。
///
/// 归属 data：进程级 UI 视图态，引擎（moodiary_sync）写、首页（moodiary_diary）读，
/// 与 [OpenDiaryRegistry] 同为跨 feature 共享的瞬态单例。feature 之间不能互引，data
/// 是所有 feature 的最低公共祖先，故置于此。
class SyncPendingState {
  /// 远端有、本地无 → 列表头部渲染占位卡。
  final Set<String> newDiaryIds;

  /// 远端较新、本地已有 → 已有卡片打「同步中」角标。
  final Set<String> updateDiaryIds;

  final Set<String> newCategoryIds;
  final Set<String> updateCategoryIds;

  const SyncPendingState({
    this.newDiaryIds = const {},
    this.updateDiaryIds = const {},
    this.newCategoryIds = const {},
    this.updateCategoryIds = const {},
  });

  static const SyncPendingState empty = SyncPendingState();

  bool get isEmpty =>
      newDiaryIds.isEmpty &&
      updateDiaryIds.isEmpty &&
      newCategoryIds.isEmpty &&
      updateCategoryIds.isEmpty;
}

/// 进程级单例：引擎写（预扫描发布 / 逐条消除 / pull 结束清空），UI 用 [listenable]
/// 监听。纯进程内状态，不持久化。
class SyncPendingTracker {
  SyncPendingTracker._();

  static final SyncPendingTracker instance = ._();

  final ValueNotifier<SyncPendingState> _notifier = ValueNotifier(
    SyncPendingState.empty,
  );

  ValueListenable<SyncPendingState> get listenable => _notifier;

  /// pull 预扫描完成后发布整份清单。
  void begin({
    required Set<String> newDiaryIds,
    required Set<String> updateDiaryIds,
    required Set<String> newCategoryIds,
    required Set<String> updateCategoryIds,
  }) {
    _notifier.value = SyncPendingState(
      newDiaryIds: newDiaryIds,
      updateDiaryIds: updateDiaryIds,
      newCategoryIds: newCategoryIds,
      updateCategoryIds: updateCategoryIds,
    );
  }

  /// 一条日记已落库（或被精确 LWW 判定跳过）→ 消除其占位 / 角标。
  void completeDiary(String id) {
    final v = _notifier.value;
    if (!v.newDiaryIds.contains(id) && !v.updateDiaryIds.contains(id)) {
      return;
    }
    _notifier.value = SyncPendingState(
      newDiaryIds: {...v.newDiaryIds}..remove(id),
      updateDiaryIds: {...v.updateDiaryIds}..remove(id),
      newCategoryIds: v.newCategoryIds,
      updateCategoryIds: v.updateCategoryIds,
    );
  }

  void completeCategory(String id) {
    final v = _notifier.value;
    if (!v.newCategoryIds.contains(id) && !v.updateCategoryIds.contains(id)) {
      return;
    }
    _notifier.value = SyncPendingState(
      newDiaryIds: v.newDiaryIds,
      updateDiaryIds: v.updateDiaryIds,
      newCategoryIds: {...v.newCategoryIds}..remove(id),
      updateCategoryIds: {...v.updateCategoryIds}..remove(id),
    );
  }

  /// pull 结束（不论成败）清空 —— 失败条目的占位不留到下一轮，
  /// 下次 pull 会重新预扫描。
  void clear() {
    if (_notifier.value.isEmpty) return;
    _notifier.value = .empty;
  }
}

/// 进程级单例：本地有改动、尚未确认上行同步的日记 id 集合（卡片「待同步」角标）。
/// [AutoSyncWatcher] 在领域事件上 [markDirty]，引擎 push 提交确认后 [clearDirty]。
/// 纯进程内、不持久化——重启即丢，下次 push 由 manifest LWW 重新推导（manifest 才是
/// 「什么已同步」的权威），角标只是瞬态 UI 提示。
class SyncDirtyTracker {
  SyncDirtyTracker._();

  static final SyncDirtyTracker instance = ._();

  final ValueNotifier<Set<String>> _notifier = ValueNotifier(const {});

  ValueListenable<Set<String>> get listenable => _notifier;

  void markDirty(String id) {
    if (id.isEmpty || _notifier.value.contains(id)) return;
    _notifier.value = {..._notifier.value, id};
  }

  void clearDirty(String id) {
    if (!_notifier.value.contains(id)) return;
    _notifier.value = {..._notifier.value}..remove(id);
  }
}
