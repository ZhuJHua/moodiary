import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'diary_repository.dart';

part 'diary_controller.g.dart';

/// 把单条 [DiaryEvent] 原地并入已加载列表（按时间倒序）。[belongs] 判定日记是否属于
/// 当前视图：增 / 改时属于则 upsert + 重排，不属于则移除（处理软删 / 还原导致的迁出）。
///
/// 内存增量与库内增量逐条一致，故分页 offset（= 已加载条数）始终与库对齐，无需重查。
List<Diary> _applyEvent(
  List<Diary> list,
  DiaryEvent event, {
  required bool Function(Diary) belongs,
}) {
  switch (event) {
    case DiaryDeleted(:final isarId):
      if (!list.any((d) => d.isarId == isarId)) return list;
      return list.where((d) => d.isarId != isarId).toList();
    case DiaryCreated(:final diary) || DiaryUpdated(:final diary):
      final index = list.indexWhere((d) => d.isarId == diary.isarId);
      if (!belongs(diary)) {
        if (index == -1) return list;
        return list.where((d) => d.isarId != diary.isarId).toList();
      }
      final updated = [...list];
      if (index == -1) {
        updated.add(diary);
      } else {
        updated[index] = diary;
      }
      updated.sort((a, b) => b.time.compareTo(a.time));
      return updated;
  }
}

/// 按 [categoryId] 维度的日记列表（`categoryId == null` 表示「全部分类」）。
/// 订阅 [DiaryRepository.diaryEvents] 按事件原地增量更新，无需重查库。
@riverpod
class DiaryController extends _$DiaryController with LoadMoreMixin<Diary> {
  late final DiaryRepository _repository = DiaryRepository.get();

  @override
  FutureOr<List<Diary>> build({String? categoryId}) async {
    final sub = _repository.diaryEvents.listen(_applyChange);
    ref.onDispose(sub.cancel);
    return init();
  }

  @override
  Future<Iterable<Diary>?> load({required int limit, required int offset}) {
    return _repository.getDiaryByCategory(
      categoryId: categoryId,
      limit: limit,
      offset: offset,
    );
  }

  void _applyChange(DiaryEvent event) {
    final list = state.value;
    if (list == null) return;
    state = AsyncValue.data(
      _applyEvent(
        list,
        event,
        // deleted=true 是同步 tombstone（永久删除后保留待推送），本地一律不可见。
        belongs: (d) =>
            d.show &&
            !d.deleted &&
            (categoryId == null || d.categoryId == categoryId),
      ),
    );
  }

  /// 软删除：移入回收站（`show = false`）。仅写库，各视图经事件流自动同步。
  Future<bool> softDeleteDiary(Diary diary) async {
    try {
      final next = diary.copyWith(
        show: false,
        lastModified: DateTime.timestamp(),
      );
      await _repository.updateADiary(oldDiary: diary, newDiary: next);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 批量软删（首页多选删除）：对当前列表里 id ∈ [ids] 的日记逐一软删，返回成功数。
  Future<int> softDeleteByIds(Set<String> ids) async {
    final list = state.value ?? const <Diary>[];
    var count = 0;
    for (final diary in list.where((d) => ids.contains(d.id)).toList()) {
      if (await softDeleteDiary(diary)) count += 1;
    }
    return count;
  }
}

/// 回收站列表（按时间倒序的所有 `show == false` 的日记）。
@riverpod
class RecycleBinDiaries extends _$RecycleBinDiaries {
  DiaryRepository get _repository => DiaryRepository.get();

  @override
  FutureOr<List<Diary>> build() async {
    final sub = _repository.diaryEvents.listen(_applyChange);
    ref.onDispose(sub.cancel);
    return _repository.getRecycleBinDiaries();
  }

  void _applyChange(DiaryEvent event) {
    final list = state.value;
    if (list == null) return;
    state = AsyncValue.data(
      _applyEvent(list, event, belongs: (d) => !d.show && !d.deleted),
    );
  }

  /// 还原为 `show = true`。仅写库，回收站与目标分类列表经事件流自动同步。
  Future<bool> restore(Diary diary) async {
    try {
      final next = diary.copyWith(
        show: true,
        lastModified: DateTime.timestamp(),
      );
      await _repository.updateADiary(oldDiary: diary, newDiary: next);
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

  Future<int> clear() async {
    final diaries = state.value ?? const <Diary>[];
    int count = 0;
    for (final d in diaries) {
      try {
        if (await _repository.deleteADiary(d.isarId)) count += 1;
      } catch (_) {}
    }
    return count;
  }
}

/// 取单条日记的「活动流」：实时跟随 [DiaryRepository.watchDiary]，彻底删除时发出 `null`。
/// id 为空发出空模板用于「新建」，此时务必显式传 [defaultType]，否则无法确定 markdown /
/// richText。
@riverpod
Stream<Diary?> getDiary(Ref ref, {String? id, DiaryType? defaultType}) async* {
  if (id == null || id.isEmpty) {
    if (defaultType == null) {
      throw ArgumentError(
        'getDiary: 新建空白日记必须显式提供 defaultType（id 为空时）',
      );
    }
    yield Diary.empty(type: defaultType);
    return;
  }
  final repository = DiaryRepository.get();
  final initial = await repository.getDiaryByBusinessId(id);
  if (initial == null) {
    yield null;
    return;
  }
  yield initial;
  yield* repository.watchDiary(initial.isarId);
}
