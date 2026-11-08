/// Category tree and the three category writes.
///
/// A category only disappears while it holds no diary, and a reparent that
/// would close a cycle is refused; both rules used to live in each client.
library;

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'diary_display.dart';
import 'diary_writes.dart';

class CategoryOps {
  CategoryOps({required this.categories, required this.diaries});

  final CategoryRepository categories;
  final DiaryRepository diaries;

  Future<List<Category>> all() => categories.getAllCategories();

  /// The tree a catalog resource or a tool renders, with visible diary counts.
  Future<({List<Map<String, dynamic>> categories, int total})> tree() async {
    final all = await categories.getAllCategories();
    final counts = (await diaries.diaryCountByCategory()).byCategory;
    return (categories: _tree(all, counts), total: all.length);
  }

  Future<Category> create({
    required String name,
    String? parentId,
    int? color,
    bool requireParent = true,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const DiaryOpsException(DiaryOpsFailure.fieldRequired);
    }
    if (parentId != null && parentId.isNotEmpty) {
      await _require(parentId, requireKnown: requireParent);
    }
    final category = Category.create(
      categoryName: trimmed,
      parentId: parentId,
      color: color,
    );
    await categories.insertACategory(category);
    return category;
  }

  /// Renames, recolours or reparents one category, leaving the other fields
  /// alone. At least one field must be sent.
  Future<Category> update({
    required String id,
    String? name,
    bool nameSet = false,
    int? color,
    bool colorSet = false,
    String? parentId,
    bool parentSet = false,
    bool rejectCycle = true,
  }) async {
    if (!nameSet && !colorSet && !parentSet) {
      throw DiaryOpsException(DiaryOpsFailure.noChanges, id: id);
    }
    final existing = await categories.getCategoryById(id);
    if (existing == null) {
      throw DiaryOpsException(DiaryOpsFailure.notFound, id: id);
    }

    var next = existing;
    if (nameSet) {
      next = next.copyWith(categoryName: name?.trim() ?? '');
    }
    if (colorSet) next = next.copyWith(color: color);
    if (parentSet) {
      if (parentId != null && parentId.isNotEmpty) {
        await _require(parentId, requireKnown: true);
        if (rejectCycle) await _rejectCycle(id, parentId);
      }
      next = next.copyWith(parentId: parentId);
    }
    next = next.copyWith(lastModified: DateTime.timestamp());
    await categories.insertACategory(next);
    return next;
  }

  /// Deletes an empty category; [deleted] is false when diaries still hold it.
  Future<({bool deleted, Category category, int children})> delete(
    String id,
  ) async {
    final existing = await categories.getCategoryById(id);
    if (existing == null) {
      throw DiaryOpsException(DiaryOpsFailure.notFound, id: id);
    }
    final all = await categories.getAllCategories();
    final children = all.where((category) => category.parentId == id).length;
    final removed = await categories.deleteACategory(id);
    return (deleted: removed, category: existing, children: children);
  }

  Future<void> _require(String id, {required bool requireKnown}) async {
    final category = await categories.getCategoryById(id);
    if (category == null && requireKnown) {
      throw DiaryOpsException(DiaryOpsFailure.notFound, categoryId: id);
    }
  }

  /// Walks up from the prospective parent; reaching [id] would close a cycle.
  Future<void> _rejectCycle(String id, String parentId) async {
    final seen = <String>{id};
    var cursor = parentId;
    while (true) {
      if (!seen.add(cursor)) {
        throw DiaryOpsException(
          DiaryOpsFailure.categoryCycle,
          id: id,
          categoryId: parentId,
        );
      }
      final parent = await categories.getCategoryById(cursor);
      final next = parent?.parentId;
      if (next == null || next.isEmpty) return;
      cursor = next;
    }
  }

  List<Map<String, dynamic>> _tree(
    List<Category> all,
    Map<String, int> counts,
  ) {
    final ids = {for (final category in all) category.id};
    final childrenOf = <String?, List<Category>>{};
    for (final category in all) {
      final parent = category.parentId;
      final key =
          parent != null && parent != category.id && ids.contains(parent)
          ? parent
          : null;
      childrenOf.putIfAbsent(key, () => []).add(category);
    }

    Map<String, dynamic> node(Category category, Set<String> path) {
      final children = <Map<String, dynamic>>[];
      for (final child in childrenOf[category.id] ?? const <Category>[]) {
        if (path.contains(child.id)) continue;
        children.add(node(child, {...path, child.id}));
      }
      return categoryInfo(
        category,
        diaryCount: counts[category.id] ?? 0,
        children: children,
      );
    }

    return [
      for (final root in childrenOf[null] ?? const <Category>[])
        node(root, {root.id}),
    ];
  }
}
