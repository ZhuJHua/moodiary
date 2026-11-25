import 'dart:async';

import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'category_repository.dart';
import 'data_providers.dart';

part 'category_controller.g.dart';

List<Category> _applyEvent(List<Category> list, CategoryEvent event) {
  switch (event) {
    case CategoryUpserted(:final category):
      if (category.deleted) {
        return list.where((c) => c.id != category.id).toList();
      }
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

@riverpod
class CategoryController extends _$CategoryController {
  CategoryRepository get _repository => ref.read(categoryRepositoryProvider);

  bool _missedEvent = false;

  @override
  FutureOr<List<Category>> build() async {
    final operationRef = ref;
    final repository = ref.watch(categoryRepositoryProvider);
    final sub = repository.categoryEvents.listen(_applyChange);
    ref.onDispose(sub.cancel);
    var list = await repository.getAllCategories();
    for (var i = 0; operationRef.mounted && _missedEvent && i < 3; i++) {
      _missedEvent = false;
      list = await repository.getAllCategories();
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
  final order = ref.watch(
    kvValueOrProvider<List<String>>(
      MoodiaryKVs.categoryOrder,
      const <String>[],
    ),
  );
  final async = ref.watch(categoryControllerProvider);
  return async.whenData((categories) => applyCategoryOrder(categories, order));
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
  void invalidate(Object _) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 200), ref.invalidateSelf);
  }

  final sub = diaryRepo.diaryEvents.listen(invalidate);
  final categories = ref
      .watch(categoryRepositoryProvider)
      .categoryEvents
      .listen(invalidate);
  ref.onDispose(() {
    debounce?.cancel();
    sub.cancel();
    categories.cancel();
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
