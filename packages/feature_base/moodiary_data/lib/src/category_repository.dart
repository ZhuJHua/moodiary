import 'dart:async';

import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'db/database.dart';
import 'db/db_codec.dart';

@lazySingleton
class CategoryRepository {
  CategoryRepository(this._db);

  final MoodiaryDatabase _db;

  final StreamController<CategoryEvent> _events =
      StreamController<CategoryEvent>.broadcast();

  Stream<CategoryEvent> get categoryEvents => _events.stream;

  static Category _toCategory(CategoryRow r) => Category(
    id: r.id,
    categoryName: r.name,
    lastModified: dbToTime(r.lastModified),
    parentId: r.parentId,
    color: r.color,
    deleted: r.deleted != 0,
  );

  static CategoriesCompanion _toCompanion(Category c) =>
      CategoriesCompanion.insert(
        id: c.id,
        name: c.categoryName,
        lastModified: dbTime(c.lastModified),
        parentId: Value(c.parentId),
        color: Value(c.color),
        deleted: Value(c.deleted ? 1 : 0),
      );

  Future<List<Category>> getAllCategories() => _categories(activeOnly: true);

  Future<List<Category>> getAllCategoriesForSync() =>
      _categories(activeOnly: false);

  Future<List<Category>> _categories({required bool activeOnly}) async {
    final query = _db.select(_db.categories)
      ..orderBy([(c) => OrderingTerm.asc(c.id)]);
    if (activeOnly) query.where((c) => c.deleted.equals(0));
    final rows = await query.get();
    return [for (final r in rows) _toCategory(r)];
  }

  Future<Category?> getCategoryById(String id) async {
    final row = await (_db.select(
      _db.categories,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toCategory(row);
  }

  Future<void> insertACategory(
    Category category, {
    bool fromSync = false,
  }) async {
    await _db.transaction(() async {
      await _db
          .into(_db.categories)
          .insertOnConflictUpdate(_toCompanion(category));
      await (_db.delete(
            _db.tombstones,
          )..where((t) => t.key.equals(SyncTombstone.categoryKey(category.id))))
          .go();
    });
    _events.add(CategoryUpserted(category, fromSync: fromSync));
  }

  Future<bool> deleteACategory(String id) async {
    final rows =
        await (_db.update(
          _db.categories,
        )..where((c) => c.id.equals(id) & c.deleted.equals(0))).writeReturning(
          CategoriesCompanion(
            deleted: const Value(1),
            lastModified: Value(dbTime(DateTime.timestamp())),
          ),
        );
    if (rows.isEmpty) return false;
    _events.add(CategoryUpserted(_toCategory(rows.single)));
    return true;
  }
}
