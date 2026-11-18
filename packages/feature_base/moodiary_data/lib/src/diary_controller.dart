import 'package:flutter/foundation.dart' show setEquals;
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'category_repository.dart';
import 'diary_repository.dart';
import 'loadmore.dart';
import 'tag_repository.dart';

part 'diary_controller.g.dart';

Comparator<Diary> diarySortComparator(DiarySort sort) => switch (sort) {
  // 第二排序键必须与 SQL 的 `, id DESC` 逐字段一致（分页 offset 依赖对齐）
  .timeDesc => (a, b) {
    final c = b.time.compareTo(a.time);
    return c != 0 ? c : b.id.compareTo(a.id);
  },
  .timeAsc => (a, b) {
    final c = a.time.compareTo(b.time);
    return c != 0 ? c : a.id.compareTo(b.id);
  },
  .lastModifiedDesc => (a, b) {
    final c = b.lastModified.compareTo(a.lastModified);
    return c != 0 ? c : b.id.compareTo(a.id);
  },
};

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
  late final _repository = getIt<DiaryRepository>();
  Set<String> _activeCategories = {};
  Set<String> _tagIdsForName = {};

  DiarySort get _sort => .getType(MoodiaryKVs.homeSortMode.get()!);

  @override
  FutureOr<List<Diary>> build({
    String? categoryId,
    bool uncategorized = false,
    String? tagName,
  }) async {
    final sub = _repository.diaryEvents.listen(_applyChange);
    ref.onDispose(sub.cancel);
    final sortNotifier = MoodiaryKVs.homeSortMode.getNotifier();
    void onSortChanged() => refresh();
    sortNotifier.addListener(onSortChanged);
    ref.onDispose(() => sortNotifier.removeListener(onSortChanged));
    if (uncategorized) {
      final buildRef = ref;
      final categories = getIt<CategoryRepository>();
      final sub = categories.categoryEvents.listen(
        (_) => buildRef.invalidateSelf(),
      );
      buildRef.onDispose(sub.cancel);
      final active = await categories.getAllCategories();
      if (!buildRef.mounted) return [];
      _activeCategories = {for (final c in active) c.id};
      return init(refreshFirst: true);
    }
    if (tagName != null) {
      final buildRef = ref;
      final tags = getIt<TagRepository>();
      Future<Set<String>> liveIds() async => {
        for (final tag in await tags.getAllTags())
          if (tag.name == tagName) tag.id,
      };

      final initialIds = liveIds();
      final sub = tags.tagEvents.listen((_) async {
        await initialIds;
        if (!buildRef.mounted) return;
        final ids = await liveIds();
        if (buildRef.mounted && !setEquals(ids, _tagIdsForName)) {
          buildRef.invalidateSelf();
        }
      });
      buildRef.onDispose(sub.cancel);
      final ids = await initialIds;
      if (!buildRef.mounted) return [];
      _tagIdsForName = ids;
      return init(refreshFirst: true);
    }
    return init();
  }

  @override
  Future<Iterable<Diary>?> load({required int limit, required int offset}) {
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
    if (list == null) {
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
    try {
      await _repository.setVisibility(diary, show: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<int> softDeleteByIds(Set<String> ids) async {
    final list = state.value ?? const <Diary>[];
    var count = 0;
    for (final diary in list.where((d) => ids.contains(d.id)).toList()) {
      try {
        await _repository.setVisibility(diary, show: false);
        count += 1;
      } catch (e, s) {
        logger.e('soft delete failed: ${diary.id}', error: e, stackTrace: s);
      }
    }
    return count;
  }
}

@riverpod
class RecycleBinDiaries extends _$RecycleBinDiaries {
  late final _repository = getIt<DiaryRepository>();

  bool _missedEvent = false;

  @override
  FutureOr<List<Diary>> build() async {
    final sub = _repository.diaryEvents.listen(_applyChange);
    ref.onDispose(sub.cancel);
    var list = await _repository.getRecycleBinDiaries();
    for (var i = 0; _missedEvent && i < 3; i++) {
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
    try {
      await _repository.setVisibility(diary, show: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> permanentDelete(String id) async {
    try {
      return await _repository.deleteADiary(id);
    } catch (_) {
      return false;
    }
  }

  Future<int> clear() async {
    final diaries = state.value ?? const <Diary>[];
    int count = 0;
    for (final d in diaries) {
      try {
        if (await _repository.deleteADiary(d.id)) count += 1;
      } catch (e, s) {
        logger.e('recycle clear failed: ${d.id}', error: e, stackTrace: s);
      }
    }
    return count;
  }
}
