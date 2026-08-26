import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'diary_repository.dart';
import 'loadmore.dart';
import 'repository_providers.dart';

part 'diary_controller.g.dart';

Comparator<Diary> diarySortComparator(DiarySort sort) => switch (sort) {
  .timeDesc => (a, b) {
    final c = b.time.compareTo(a.time);
    return c != 0 ? c : b.isarId.compareTo(a.isarId);
  },
  .timeAsc => (a, b) {
    final c = a.time.compareTo(b.time);
    return c != 0 ? c : a.isarId.compareTo(b.isarId);
  },
  .lastModifiedDesc => (a, b) {
    final c = b.lastModified.compareTo(a.lastModified);
    return c != 0 ? c : b.isarId.compareTo(a.isarId);
  },
};

/// 把单条 [DiaryEvent] 原地并入已加载列表。[belongs] 判定日记是否属于当前视图：增 /
/// 改时属于则 upsert + 重排，不属于则移除（处理软删 / 还原导致的迁出）。
///
/// 内存增量与库内增量逐条一致，故分页 offset（= 已加载条数）始终与库对齐，无需重查。
List<Diary> applyDiaryEvent(
  List<Diary> list,
  DiaryEvent event, {
  required bool Function(Diary) belongs,
  Comparator<Diary>? compare,
  bool mayHaveMore = false,
}) {
  final cmp = compare ?? diarySortComparator(.timeDesc);
  switch (event) {
    case DiaryDeleted(:final isarId):
      if (!list.any((d) => d.isarId == isarId)) return list;
      return list.where((d) => d.isarId != isarId).toList();
    case DiaryCreated(:final diary) || DiaryUpdated(:final diary):
      final without = list.where((d) => d.isarId != diary.isarId).toList();
      final removed = without.length != list.length;
      if (!belongs(diary)) return removed ? without : list;
      if (mayHaveMore && without.isNotEmpty && cmp(diary, without.last) > 0) {
        return removed ? without : list;
      }
      return [...without, diary]..sort(cmp);
  }
}

/// 按 [categoryId] 维度的日记列表（`categoryId == null` 表示「全部分类」）。
/// 订阅 [DiaryRepository.diaryEvents] 按事件原地增量更新，无需重查库。
@riverpod
class DiaryController extends _$DiaryController with LoadMoreMixin<Diary> {
  DiaryRepository get _repository => ref.read(diaryRepositoryProvider);

  DiarySort get _sort => .getType(MoodiaryKVs.homeSortMode.get()!);

  @override
  FutureOr<List<Diary>> build({
    String? categoryId,
    bool uncategorized = false,
  }) async {
    final sub = _repository.diaryEvents.listen(_applyChange);
    ref.onDispose(sub.cancel);
    final sortNotifier = MoodiaryKVs.homeSortMode.getNotifier();
    void onSortChanged() => refresh();
    sortNotifier.addListener(onSortChanged);
    ref.onDispose(() => sortNotifier.removeListener(onSortChanged));
    return init();
  }

  @override
  Future<Iterable<Diary>?> load({required int limit, required int offset}) {
    return _repository.getDiaryByCategory(
      categoryId: categoryId,
      uncategorized: uncategorized,
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
            (uncategorized
                ? d.categoryId == null
                : categoryId == null || d.categoryId == categoryId),
        compare: diarySortComparator(_sort),
        mayHaveMore: !noMore,
      ),
    );
  }

  /// 软删除：移入回收站（`show = false`）。仅写库，各视图经事件流自动同步。
  Future<bool> softDeleteDiary(Diary diary) async {
    try {
      await _repository.setVisibility(diary, show: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 批量软删（首页多选删除）：对当前列表里 id ∈ [ids] 的日记逐一软删，返回成功数。
  /// 仓储在循环外取一次：`_repository` 每次都要碰 ref，批量操作耗时秒级，期间页面
  /// 退出（autoDispose 回收）会让 ref.read 抛 UnmountedRefException——单例本身
  /// 跨 dispose 持有是安全的。
  Future<int> softDeleteByIds(Set<String> ids) async {
    final list = state.value ?? const <Diary>[];
    final repo = _repository;
    var count = 0;
    for (final diary in list.where((d) => ids.contains(d.id)).toList()) {
      try {
        await repo.setVisibility(diary, show: false);
        count += 1;
      } catch (e, s) {
        logger.e('soft delete failed: ${diary.id}', error: e, stackTrace: s);
      }
    }
    return count;
  }
}

/// 回收站列表（按时间倒序的所有 `show == false` 的日记）。
@riverpod
class RecycleBinDiaries extends _$RecycleBinDiaries {
  DiaryRepository get _repository => ref.read(diaryRepositoryProvider);

  // 首次加载期间事件无处可并，标记后补一次重查（同 LoadMoreMixin.markMissedEvent）。
  bool _missedEvent = false;

  @override
  FutureOr<List<Diary>> build() async {
    final sub = _repository.diaryEvents.listen(_applyChange);
    ref.onDispose(sub.cancel);
    var list = await _repository.getRecycleBinDiaries();
    if (_missedEvent) {
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

  /// 还原为 `show = true`。仅写库，回收站与目标分类列表经事件流自动同步。
  Future<bool> restore(Diary diary) async {
    try {
      await _repository.setVisibility(diary, show: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> permanentDelete(int isarId) async {
    try {
      return await _repository.deleteADiary(isarId);
    } catch (_) {
      return false;
    }
  }

  /// 清空回收站。仓储在循环外取一次——逐篇删除（含删媒体文件）耗时秒级，
  /// 期间用户返回上一页会销毁本 provider，循环里再碰 `_repository`（ref.read）
  /// 就抛 UnmountedRefException 且被 catch 吞掉，剩余日记留在回收站而 count
  /// 谎报成功；单例跨 dispose 持有是安全的。
  Future<int> clear() async {
    final diaries = state.value ?? const <Diary>[];
    final repo = _repository;
    int count = 0;
    for (final d in diaries) {
      try {
        if (await repo.deleteADiary(d.isarId)) count += 1;
      } catch (e, s) {
        logger.e('recycle clear failed: ${d.id}', error: e, stackTrace: s);
      }
    }
    return count;
  }
}

/// 取单条日记的「活动流」：实时跟随 [DiaryRepository.watchDiary]，彻底删除时发出 `null`。
/// id 为空发出空模板用于「新建」，此时务必显式传 [defaultType]，否则无法确定 markdown /
/// richText。
@riverpod
Stream<Diary?> getDiary(
  Ref ref, {
  String? id,
  DiaryType? defaultType,
  String? defaultCategoryId,
}) async* {
  if (id == null || id.isEmpty) {
    if (defaultType == null) {
      throw ArgumentError('getDiary: 新建空白日记必须显式提供 defaultType（id 为空时）');
    }
    final empty = Diary.empty(type: defaultType);
    yield defaultCategoryId == null
        ? empty
        : empty.copyWith(categoryId: defaultCategoryId);
    return;
  }
  final repository = ref.watch(diaryRepositoryProvider);
  final initial = await repository.getDiaryByBusinessId(id);
  if (initial == null) {
    yield null;
    return;
  }
  yield initial;
  yield* repository.watchDiary(initial.isarId);
}
