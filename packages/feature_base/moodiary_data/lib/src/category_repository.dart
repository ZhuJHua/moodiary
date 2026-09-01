import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:moodiary_models/moodiary_models.dart';

import 'db/database.dart';
import 'db/db_codec.dart';

class CategoryRepository {
  CategoryRepository._(this._db);

  factory CategoryRepository.get() => _instance;

  @visibleForTesting
  CategoryRepository.forTesting(this._db);

  static final CategoryRepository _instance = ._(MoodiaryDatabase.get());

  final MoodiaryDatabase _db;

  /// 单例随应用整个生命周期存活，故此 controller 不主动关闭。
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

  /// 全量分类（表内即全部活跃行，删除后行硬删、事实入墓碑表）。
  /// 错误约定：失败直接抛（本包统一），调用方按需 catch 且至少 logger.e——
  /// 别把库故障吞成空列表。
  Future<List<Category>> getAllCategories() async {
    final rows = await (_db.select(
      _db.categories,
    )..orderBy([(c) => OrderingTerm.asc(c.id)])).get();
    return [for (final r in rows) _toCategory(r)];
  }

  /// 按 id 取单个分类。
  Future<Category?> getCategoryById(String id) async {
    final row = await (_db.select(
      _db.categories,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toCategory(row);
  }

  /// 同步 pull 应用远端分类墓碑：行硬删 + 写墓碑，无 hasDiary 守卫（远端删除即
  /// 事实；本地日记残留的 categoryId 悬挂由 repairData 清理）。返回写入的墓碑行。
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

  /// [fromSync] = 该写入由活跃云后端的 pull 落库（远端已持有），事件携带此标记
  /// 供 AutoSyncWatcher 免除回声推送。
  Future<void> insertACategory(
    Category category, {
    bool fromSync = false,
  }) async {
    await _db.transaction(() async {
      await _db
          .into(_db.categories)
          .insertOnConflictUpdate(_toCompanion(category));
      // 复活闸门：同 id 的同步墓碑连带清除（同步下载 / 重建同名 id 场景）。
      await (_db.delete(
            _db.tombstones,
          )..where((t) => t.key.equals(SyncTombstone.categoryKey(category.id))))
          .go();
    });
    _events.add(CategoryUpserted(category, fromSync: fromSync));
  }

  /// 本地删除：仅当分类下没有日记时成功；行硬删 + 写同步墓碑。
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
