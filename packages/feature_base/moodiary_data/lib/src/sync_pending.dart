import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

class SyncPendingState {
  final Set<String> newDiaryIds;

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

@singleton
class SyncPendingTracker {
  final ValueNotifier<SyncPendingState> _notifier = ValueNotifier(
    SyncPendingState.empty,
  );

  ValueListenable<SyncPendingState> get listenable => _notifier;

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

  void clear() {
    if (_notifier.value.isEmpty) return;
    _notifier.value = .empty;
  }
}

@singleton
class SyncDirtyTracker {
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
