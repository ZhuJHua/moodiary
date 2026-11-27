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
}) => _applyDiaryEvent(
  list,
  event,
  belongs: belongs,
  idOf: (diary) => diary.id,
  project: (diary) => diary,
  compare: compare ?? diarySortComparator(.timeDesc),
  mayHaveMore: mayHaveMore,
);

List<T> _applyDiaryEvent<T>(
  List<T> list,
  DiaryEvent event, {
  required bool Function(Diary) belongs,
  required String Function(T) idOf,
  required T Function(Diary) project,
  required Comparator<T> compare,
  required bool mayHaveMore,
}) {
  switch (event) {
    case DiaryDeleted(:final id):
      if (!list.any((item) => idOf(item) == id)) return list;
      return list.where((item) => idOf(item) != id).toList();
    case DiaryCreated(:final diary) || DiaryUpdated(:final diary):
      final index = list.indexWhere((item) => idOf(item) == diary.id);
      List<T> removeExisting() =>
          index == -1 ? list : (list.toList()..removeAt(index));
      if (!belongs(diary)) return removeExisting();
      final item = project(diary);
      if (index != -1 && list[index] == item) return list;
      final tail = index == list.length - 1 ? list.length - 2 : list.length - 1;
      if (mayHaveMore && tail >= 0 && compare(item, list[tail]) > 0) {
        return removeExisting();
      }
      final updated = list.toList();
      if (index == -1) {
        updated.add(item);
      } else {
        updated[index] = item;
      }
      return updated..sort(compare);
  }
}

class DiaryListState extends PagedList<DiarySummary> {
  final DiarySort sort;

  DiaryListState({
    required super.items,
    required this.sort,
    required super.hasMore,
    super.isLoadingMore,
    super.loadMoreError,
  });

  @override
  DiaryListState copyWith({
    List<DiarySummary>? items,
    DiarySort? sort,
    bool? hasMore,
    bool? isLoadingMore,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) => DiaryListState(
    items: items ?? this.items,
    sort: sort ?? this.sort,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreError: clearLoadMoreError
        ? null
        : loadMoreError ?? this.loadMoreError,
  );
}

@riverpod
class DiaryController extends _$DiaryController
    with LoadMoreMixin<DiarySummary, DiaryListState> {
  late DiaryRepository _repository;
  Set<String> _activeCategories = {};
  Set<String> _tagIdsForName = {};

  late DiarySort _sort;
  Future<void>? _membership;

  @override
  FutureOr<DiaryListState> build({
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
    return init();
  }

  @override
  DiaryListState buildPageState({
    required List<DiarySummary> items,
    required bool hasMore,
    required bool isLoadingMore,
    Object? loadMoreError,
  }) => DiaryListState(
    items: items,
    sort: _sort,
    hasMore: hasMore,
    isLoadingMore: isLoadingMore,
    loadMoreError: loadMoreError,
  );

  @override
  Future<Iterable<DiarySummary>?> load({
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
    return _repository.getDiarySummariesByCategory(
      categoryId: categoryId,
      uncategorized: uncategorized,
      tagName: tagName,
      limit: limit,
      offset: offset,
      sort: _sort,
    );
  }

  void _applyChange(DiaryEvent event) {
    final page = state.value;
    if (page == null ||
        _membership != null ||
        state.hasError ||
        state.isReloading ||
        isRefreshing) {
      markMissedEvent();
      return;
    }
    markPrefixMutated();
    final items = _applyDiaryEvent(
      page.items,
      event,
      belongs: (d) =>
          d.show &&
          (tagName != null
              ? d.tagIds.any(_tagIdsForName.contains)
              : uncategorized
              ? !_activeCategories.contains(d.categoryId)
              : categoryId == null || d.categoryId == categoryId),
      idOf: (diary) => diary.id,
      project: diarySummaryFromDiary,
      compare: diarySummarySortComparator(page.sort),
      mayHaveMore: page.hasMore,
    );
    if (!identical(items, page.items)) {
      state = .data(page.copyWith(items: items));
    }
  }

  Future<int> softDeleteByIds(Set<String> ids) async {
    final repository = _repository;
    var count = 0;
    for (final id in ids) {
      try {
        final diary = await repository.getDiaryByBusinessId(id);
        if (diary == null || !diary.show) continue;
        await repository.setVisibility(diary, show: false);
        count += 1;
      } catch (e, s) {
        logger.e('soft delete failed: $id', error: e, stackTrace: s);
      }
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
    final items = applyDiaryEvent(list, event, belongs: (d) => !d.show);
    if (!identical(items, list)) state = .data(items);
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
