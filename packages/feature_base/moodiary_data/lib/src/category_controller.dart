import 'dart:async';

import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'category_repository.dart';
import 'repository_providers.dart';

part 'category_controller.g.dart';

/// 把单条 [CategoryEvent] 原地并入列表（按 id 升序）。
List<Category> _applyEvent(List<Category> list, CategoryEvent event) {
  switch (event) {
    case CategoryDeleted(:final id):
      if (!list.any((c) => c.id == id)) return list;
      return list.where((c) => c.id != id).toList();
    case CategoryUpserted(:final category):
      final index = list.indexWhere((c) => c.id == category.id);
      final updated = [...list];
      if (index == -1) {
        updated.add(category);
      } else {
        updated[index] = category;
      }
      updated.sort((a, b) => a.id.compareTo(b.id));
      return updated;
  }
}

/// 订阅 [CategoryRepository.categoryEvents]，按事件原地增量更新，无需重查库。
@riverpod
class CategoryController extends _$CategoryController {
  CategoryRepository get _repository => ref.read(categoryRepositoryProvider);

  // 首次加载期间事件无处可并，标记后补一次重查（同 LoadMoreMixin.markMissedEvent）。
  bool _missedEvent = false;

  @override
  FutureOr<List<Category>> build() async {
    final sub = _repository.categoryEvents.listen(_applyChange);
    ref.onDispose(sub.cancel);
    var list = await _repository.getAllCategories();
    // 循环补偿（上限防饥饿）：补查期间 state 仍是 loading，事件只能置标记——
    // 单次检查过后标记就没人消费了（LoadMoreMixin 版无此洞：refresh 时 state 已有值）。
    for (var i = 0; _missedEvent && i < 3; i++) {
      _missedEvent = false;
      list = await _repository.getAllCategories();
    }
    return list;
  }

  void _applyChange(CategoryEvent event) {
    final list = state.value;
    if (list == null) {
      _missedEvent = true;
      return;
    }
    state = .data(_applyEvent(list, event));
  }

  Future<bool> upsertCategory(Category category) async {
    try {
      await _repository.insertACategory(category);
      return true;
    } catch (e, s) {
      logger.e('upsert category failed', error: e, stackTrace: s);
      return false;
    }
  }

  /// 删除分类（行硬删 + 同步墓碑），仅当其下没有日记时成功。
  Future<bool> deleteCategory(String id) async {
    try {
      return await _repository.deleteACategory(id);
    } catch (e, s) {
      logger.e('delete category failed', error: e, stackTrace: s);
      return false;
    }
  }
}

@riverpod
AsyncValue<List<Category>> orderedCategories(Ref ref) {
  final orderNotifier = MoodiaryKVs.categoryOrder.getNotifierOr(
    const <String>[],
  );
  void onOrderChanged() => ref.invalidateSelf();
  orderNotifier.addListener(onOrderChanged);
  ref.onDispose(() => orderNotifier.removeListener(onOrderChanged));
  final async = ref.watch(categoryControllerProvider);
  return async.whenData(
    (categories) => applyCategoryOrder(categories, orderNotifier.value),
  );
}

List<Category> applyCategoryOrder(
  List<Category> categories,
  List<String> order,
) {
  if (order.isEmpty) return categories;
  final byId = {for (final c in categories) c.id: c};
  final result = <Category>[];
  for (final id in order) {
    final c = byId.remove(id);
    if (c != null) result.add(c);
  }
  result.addAll(byId.values.toList()..sort((a, b) => a.id.compareTo(b.id)));
  return result;
}

@riverpod
Future<({Map<String, int> byCategory, int total})> categoryDiaryCounts(
  Ref ref,
) async {
  final diaryRepo = ref.watch(diaryRepositoryProvider);
  Timer? debounce;
  final sub = diaryRepo.diaryEvents.listen((_) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 200), ref.invalidateSelf);
  });
  ref.onDispose(() {
    debounce?.cancel();
    sub.cancel();
  });
  return diaryRepo.diaryCountByCategory();
}

@riverpod
Future<Category?> getCategory(Ref ref, {required String id}) async {
  final allCategory = await ref.watch(categoryControllerProvider.future);
  for (final category in allCategory) {
    if (category.id == id) return category;
  }
  return null;
}

@riverpod
Category? categoryById(Ref ref, String? id) {
  if (id == null) return null;
  final cats = ref.watch(categoryControllerProvider).value ?? const [];
  for (final c in cats) {
    if (c.id == id) return c;
  }
  return null;
}
