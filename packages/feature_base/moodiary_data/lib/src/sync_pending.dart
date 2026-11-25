import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_pending.g.dart';

class SyncPendingState {
  final Set<String> newDiaryIds;

  final Set<String> updateDiaryIds;

  final Set<String> newCategoryIds;
  final Set<String> updateCategoryIds;

  SyncPendingState({
    Set<String> newDiaryIds = const {},
    Set<String> updateDiaryIds = const {},
    Set<String> newCategoryIds = const {},
    Set<String> updateCategoryIds = const {},
  }) : newDiaryIds = Set.unmodifiable(newDiaryIds),
       updateDiaryIds = Set.unmodifiable(updateDiaryIds),
       newCategoryIds = Set.unmodifiable(newCategoryIds),
       updateCategoryIds = Set.unmodifiable(updateCategoryIds);

  static final SyncPendingState empty = SyncPendingState();

  bool get isEmpty =>
      newDiaryIds.isEmpty &&
      updateDiaryIds.isEmpty &&
      newCategoryIds.isEmpty &&
      updateCategoryIds.isEmpty;
}

@Riverpod(keepAlive: true, name: 'syncPendingStateProvider')
class SyncPendingTracker extends _$SyncPendingTracker {
  @override
  SyncPendingState build() => SyncPendingState.empty;

  void begin({
    required Set<String> newDiaryIds,
    required Set<String> updateDiaryIds,
    required Set<String> newCategoryIds,
    required Set<String> updateCategoryIds,
  }) {
    state = SyncPendingState(
      newDiaryIds: newDiaryIds,
      updateDiaryIds: updateDiaryIds,
      newCategoryIds: newCategoryIds,
      updateCategoryIds: updateCategoryIds,
    );
  }

  void completeDiary(String id) {
    final v = state;
    if (!v.newDiaryIds.contains(id) && !v.updateDiaryIds.contains(id)) {
      return;
    }
    state = SyncPendingState(
      newDiaryIds: {...v.newDiaryIds}..remove(id),
      updateDiaryIds: {...v.updateDiaryIds}..remove(id),
      newCategoryIds: v.newCategoryIds,
      updateCategoryIds: v.updateCategoryIds,
    );
  }

  void completeCategory(String id) {
    final v = state;
    if (!v.newCategoryIds.contains(id) && !v.updateCategoryIds.contains(id)) {
      return;
    }
    state = SyncPendingState(
      newDiaryIds: v.newDiaryIds,
      updateDiaryIds: v.updateDiaryIds,
      newCategoryIds: {...v.newCategoryIds}..remove(id),
      updateCategoryIds: {...v.updateCategoryIds}..remove(id),
    );
  }

  void clear() {
    if (state.isEmpty) return;
    state = .empty;
  }
}

@Riverpod(keepAlive: true, name: 'syncDirtyDiaryIdsProvider')
class SyncDirtyTracker extends _$SyncDirtyTracker {
  @override
  Set<String> build() => const {};

  Set<String> consume() {
    final dirty = state;
    clear();
    return dirty;
  }

  void clear() {
    if (state.isNotEmpty) state = const {};
  }

  void markDirty(String id) {
    if (id.isEmpty || state.contains(id)) return;
    state = Set.unmodifiable({...state, id});
  }

  void clearDirty(String id) {
    if (!state.contains(id)) return;
    state = Set.unmodifiable({...state}..remove(id));
  }
}
