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
  );

  static CategoriesCompanion _toCompanion(Category c) =>
      CategoriesCompanion.insert(
        id: c.id,
        name: c.categoryName,
        lastModified: dbTime(c.lastModified),
        parentId: Value(c.parentId),
        color: Value(c.color),
      );

  Future<List<Category>> getAllCategories() async {
    final rows = await (_db.select(
      _db.categories,
    )..orderBy([(c) => OrderingTerm.asc(c.id)])).get();
    return [for (final r in rows) _toCategory(r)];
  }

  Future<Category?> getCategoryById(String id) async {
    final row = await (_db.select(
      _db.categories,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toCategory(row);
  }

  Future<SyncTombstone> tombstoneCategoryForSync(
    String id, {
    bool fromSync = false,
  }) async {
    final tombstone = SyncTombstone.forCategory(id, at: .timestamp());
    await _db.transaction(() async {
      await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
      await _db
          .into(_db.tombstones)
          .insertOnConflictUpdate(
            TombstonesCompanion.insert(
              key: tombstone.key,
              timeMs: tombstone.timeMs,
              pushedBackendsJson: Value(dbStringList(tombstone.pushedBackends)),
            ),
          );
    });
    _events.add(CategoryDeleted(id, fromSync: fromSync));
    return tombstone;
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
    final tombstone = SyncTombstone.forCategory(id, at: .timestamp());
    final deleted = await _db.transaction(() async {
      final hasDiary =
          await (_db.select(_db.diaries)
                ..where((d) => d.categoryId.equals(id))
                ..limit(1))
              .getSingleOrNull() !=
          null;
      if (hasDiary) return false;
      final removed = await (_db.delete(
        _db.categories,
      )..where((c) => c.id.equals(id))).go();
      if (removed == 0) return false;
      await _db
          .into(_db.tombstones)
          .insertOnConflictUpdate(
            TombstonesCompanion.insert(
              key: tombstone.key,
              timeMs: tombstone.timeMs,
              pushedBackendsJson: Value(dbStringList(tombstone.pushedBackends)),
            ),
          );
      return true;
    });
    if (deleted) _events.add(CategoryDeleted(id));
    return deleted;
  }
}
