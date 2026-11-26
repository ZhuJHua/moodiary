import 'package:flutter/foundation.dart' show setEquals;
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'diary_controller.g.dart';

List<Diary> applyDiaryEvent(
  List<Diary> list,
  DiaryEvent event, {
  required bool Function(Diary) belongs,
  Comparator<Diary>? compare,
  bool mayHaveMore = false,
}) {
  final cmp = compare ?? diarySortComparator(.timeDesc);
  switch (event) {
    case DiaryDeleted(:final id):
      if (!list.any((d) => d.id == id)) return list;
      return list.where((d) => d.id != id).toList();
    case DiaryCreated(:final diary) || DiaryUpdated(:final diary):
      final without = list.where((d) => d.id != diary.id).toList();
      final removed = without.length != list.length;
      if (!belongs(diary)) return removed ? without : list;
      if (mayHaveMore && without.isNotEmpty && cmp(diary, without.last) > 0) {
        return removed ? without : list;
      }
      return [...without, diary]..sort(cmp);
  }
}

@riverpod
class DiaryController extends _$DiaryController with LoadMoreMixin<Diary> {
  late DiaryRepository _repository;
  Set<String> _activeCategories = {};
  Set<String> _tagIdsForName = {};

  late DiarySort _sort;
  Future<void>? _membership;

  @override
  FutureOr<List<Diary>> build({
    String? categoryId,
    bool uncategorized = false,
    String? tagName,
  }) {
    _repository = ref.watch(diaryRepositoryProvider);
    _sort = DiarySort.getType(
      ref.watch(kvValueProvider(MoodiaryKVs.homeSortMode)),
    );
    final sub = _repository.diaryEvents.listen(_applyChange);
    ref.onDispose(sub.cancel);
    final operationRef = ref;
    _membership = null;
    if (uncategorized) {
      final categories = ref.watch(categoryRepositoryProvider);
      final categorySub = categories.categoryEvents.listen(
        (_) => operationRef.invalidateSelf(),
      );
      ref.onDispose(categorySub.cancel);
      _membership = categories.getAllCategories().then((categories) {
        if (operationRef.mounted) {
          _activeCategories = {for (final category in categories) category.id};
        }
      });
    } else if (tagName != null) {
      final tags = ref.watch(tagRepositoryProvider);
      Future<Set<String>> liveIds() async => {
        for (final tag in await tags.getAllTags())
          if (tag.name == tagName) tag.id,
      };
      final initialIds = liveIds().then((ids) {
        if (operationRef.mounted) _tagIdsForName = ids;
      });
      _membership = initialIds;
      final tagSub = tags.tagEvents.listen((_) async {
        await initialIds;
        if (!operationRef.mounted) return;
        final ids = await liveIds();
        if (operationRef.mounted && !setEquals(ids, _tagIdsForName)) {
          operationRef.invalidateSelf();
        }
      });
      ref.onDispose(tagSub.cancel);
    }
    return init(refreshFirst: true);
  }

  @override
  Future<Iterable<Diary>?> load({
    required int limit,
    required int offset,
  }) async {
    final operationRef = ref;
    final membership = _membership;
    if (membership != null) {
      await membership;
      if (!operationRef.mounted) return null;
      _membership = null;
    }
    return _repository.getDiaryByCategory(
      categoryId: categoryId,
      uncategorized: uncategorized,
      tagName: tagName,
      limit: limit,
      offset: offset,
      sort: _sort,
    );
  }

  void _applyChange(DiaryEvent event) {
    final list = state.value;
    if (list == null || _membership != null || state.isReloading) {
      markMissedEvent();
      return;
    }
    state = .data(
      applyDiaryEvent(
        list,
        event,
        belongs: (d) =>
            d.show &&
            (tagName != null
                ? d.tagIds.any(_tagIdsForName.contains)
                : uncategorized
                ? !_activeCategories.contains(d.categoryId)
                : categoryId == null || d.categoryId == categoryId),
        compare: diarySortComparator(_sort),
        mayHaveMore: !noMore,
      ),
    );
  }

  Future<bool> softDeleteDiary(Diary diary) async {
    final operationRef = ref;
    try {
      await _repository.setVisibility(diary, show: false);
      return operationRef.mounted;
    } catch (_) {
      return false;
    }
  }

  Future<int> softDeleteByIds(Set<String> ids) async {
    final operationRef = ref;
    final list = state.value ?? const <Diary>[];
    var count = 0;
    for (final diary in list.where((d) => ids.contains(d.id)).toList()) {
      try {
        await _repository.setVisibility(diary, show: false);
        count += 1;
      } catch (e, s) {
        logger.e('soft delete failed: ${diary.id}', error: e, stackTrace: s);
      }
      if (!operationRef.mounted) break;
    }
    return count;
  }
}

@riverpod
class RecycleBinDiaries extends _$RecycleBinDiaries {
  late DiaryRepository _repository;

  bool _missedEvent = false;

  @override
  FutureOr<List<Diary>> build() async {
    _repository = ref.watch(diaryRepositoryProvider);
    final operationRef = ref;
    final sub = _repository.diaryEvents.listen(_applyChange);
    ref.onDispose(sub.cancel);
    var list = await _repository.getRecycleBinDiaries();
    for (var i = 0; operationRef.mounted && _missedEvent && i < 3; i++) {
      _missedEvent = false;
      list = await _repository.getRecycleBinDiaries();
    }
    return list;
  }

  void _applyChange(DiaryEvent event) {
    final list = state.value;
    if (list == null) {
      _missedEvent = true;
      return;
    }
    state = .data(applyDiaryEvent(list, event, belongs: (d) => !d.show));
  }

  Future<bool> restore(Diary diary) async {
    final operationRef = ref;
    try {
      await _repository.setVisibility(diary, show: true);
      return operationRef.mounted;
    } catch (_) {
      return false;
    }
  }

  Future<bool> permanentDelete(String id) async {
    final operationRef = ref;
    try {
      final deleted = await _repository.deleteADiary(id);
      return operationRef.mounted && deleted;
    } catch (_) {
      return false;
    }
  }

  Future<int> clear() async {
    final repository = _repository;
    final ids = [for (final d in state.value ?? const <Diary>[]) d.id];
    int count = 0;
    for (final id in ids) {
      try {
        if (await repository.deleteADiary(id)) count += 1;
      } catch (e, s) {
        logger.e('recycle clear failed: $id', error: e, stackTrace: s);
      }
    }
    return count;
  }
}
