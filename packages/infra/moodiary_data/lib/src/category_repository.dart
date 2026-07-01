import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';

class CategoryRepository {
  CategoryRepository._(this._isar);

  factory CategoryRepository.get() => _instance;

  static final CategoryRepository _instance = CategoryRepository._(
    IsarDatabase.get().isar,
  );

  final Isar _isar;

  /// 单例随应用整个生命周期存活，故此 controller 不主动关闭。
  final StreamController<CategoryEvent> _events =
      StreamController<CategoryEvent>.broadcast();

  Stream<CategoryEvent> get categoryEvents => _events.stream;

  /// UI 用：仅返回未软删的分类。
  TaskEither<DatabaseException, List<Category>> getAllCategories() {
    return TaskEither.tryCatch(() async {
      return await _isar.categorys
          .where()
          .deletedEqualTo(false)
          .sortById()
          .findAllAsync();
    }, (e, _) => DatabaseException('Failed to fetch categories: $e'));
  }

  TaskEither<DatabaseException, List<Category>> getAllCategoriesForSync() {
    return TaskEither.tryCatch(
      () async => await _isar.categorys.where().sortById().findAllAsync(),
      (e, _) => DatabaseException('Failed to fetch categories: $e'),
    );
  }

  /// 按业务 id 取单个分类（含已软删）。
  Future<Category?> getCategoryById(String id) async {
    return await _isar.categorys.getAsync(id);
  }

  TaskEither<DatabaseException, void> insertACategory(Category category) {
    return TaskEither.tryCatch(() async {
      await _isar.writeAsync((isar) {
        isar.categorys.put(category);
      });
      _events.add(CategoryUpserted(category));
    }, (e, _) => DatabaseException('Failed to insert category: $e'));
  }

  TaskEither<DatabaseException, bool> deleteACategory(String id) {
    return TaskEither.tryCatch(() async {
      final deleted = await _isar.writeAsync((isar) {
        final hasDiary = !isar.diarys.where().categoryIdEqualTo(id).isEmpty();
        if (hasDiary) return false;
        final existing = isar.categorys.get(id);
        if (existing == null || existing.deleted) return false;
        isar.categorys.put(
          existing.copyWith(deleted: true, lastModified: DateTime.timestamp()),
        );
        return true;
      });
      if (deleted) _events.add(CategoryDeleted(id));
      return deleted;
    }, (e, _) => DatabaseException('Failed to delete category: $e'));
  }
}
