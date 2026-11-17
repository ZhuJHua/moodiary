library;

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'diary_writes.dart';

class CategoryOps {
  CategoryOps({required this.categories});

  final CategoryRepository categories;

  Future<Category> create({required String name, int? color}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const DiaryOpsException(DiaryOpsFailure.fieldRequired);
    }
    final category = Category.create(categoryName: trimmed, color: color);
    await categories.insertACategory(category);
    return category;
  }

  Future<Category> update({
    required String id,
    String? name,
    int? color,
    bool colorSet = false,
  }) async {
    if (name == null && !colorSet) {
      throw DiaryOpsException(DiaryOpsFailure.noChanges, id: id);
    }
    final existing = await categories.getCategoryById(id);
    if (existing == null) {
      throw DiaryOpsException(DiaryOpsFailure.notFound, id: id);
    }
    var next = existing;
    if (name != null) next = next.copyWith(categoryName: name.trim());
    if (colorSet) next = next.copyWith(color: color);
    next = next.copyWith(lastModified: DateTime.timestamp());
    await categories.insertACategory(next);
    return next;
  }

  Future<({bool deleted, Category category})> delete(String id) async {
    final existing = await categories.getCategoryById(id);
    if (existing == null) {
      throw DiaryOpsException(DiaryOpsFailure.notFound, id: id);
    }
    final removed = await categories.deleteACategory(id);
    return (deleted: removed, category: existing);
  }
}
