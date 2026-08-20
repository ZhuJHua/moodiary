import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

class CategoryRepository {
  CategoryRepository._(this._isar);

  factory CategoryRepository.get() => _instance;

  static final CategoryRepository _instance = ._(IsarDatabase.get().isar);

  final Isar _isar;

  /// 单例随应用整个生命周期存活，故此 controller 不主动关闭。
  final StreamController<CategoryEvent> _events =
      StreamController<CategoryEvent>.broadcast();

  Stream<CategoryEvent> get categoryEvents => _events.stream;

  /// 全量分类（表内即全部活跃行，删除后行硬删、事实入 SyncTombstone 表）。
  TaskEither<DatabaseException, List<Category>> getAllCategories() {
    return .tryCatch(
      () async => await _isar.categorys.where().sortById().findAllAsync(),
      (e, _) => DatabaseException('Failed to fetch categories: $e'),
    );
  }

  TaskEither<DatabaseException, List<Category>> getAllCategoriesForSync() =>
      getAllCategories();

  /// 按业务 id 取单个分类。
  Future<Category?> getCategoryById(String id) async {
    return await _isar.categorys.getAsync(id);
  }

  /// [fromSync] = 该写入由活跃云后端的 pull 落库（远端已持有），事件携带此标记
  /// 供 AutoSyncWatcher 免除回声推送。
  TaskEither<DatabaseException, void> insertACategory(
    Category category, {
    bool fromSync = false,
  }) {
    return .tryCatch(
      () => _putCategory(category, fromSync: fromSync),
      (e, _) => DatabaseException('Failed to insert category: $e'),
    );
  }

  TaskEither<DatabaseException, bool> deleteACategory(String id) {
    return .tryCatch(
      () => _deleteCategory(id),
      (e, _) => DatabaseException('Failed to delete category: $e'),
    );
  }

  /// 同步 pull 应用远端分类墓碑：行硬删 + 写墓碑，无 hasDiary 守卫（远端删除即
  /// 事实；本地日记残留的 categoryId 悬挂由 repairData 清理，与旧行为一致）。
  /// 返回写入的墓碑行。[fromSync] 语义同 [insertACategory]。
  Future<SyncTombstone> tombstoneCategoryForSync(
    String id, {
    bool fromSync = false,
  }) async {
    final tombstone = SyncTombstone.forCategory(id, at: .timestamp());
    await _isar.writeAsync((isar) {
      isar.categorys.delete(id);
      isar.syncTombstones.put(tombstone);
    });
    _events.add(CategoryDeleted(id, fromSync: fromSync));
    return tombstone;
  }

  // 写操作抽成独立方法（而非直接放进 TaskEither 的闭包里）：`_isar.writeAsync` 的回调会被
  // 送进后台 isolate 执行（Isar.run），若回调嵌在会捕获 `this` 的闭包里，就会连带捕获不可
  // 发送的 `_isar`，抛「object is unsendable」。独立方法里的回调只捕获数据参数（可发送）。
  Future<void> _putCategory(Category category, {bool fromSync = false}) async {
    // 复活闸门：同 id 的同步墓碑连带清除（同步下载 / 重建同名 id 场景）。
    final tombstoneId = fastHash(SyncTombstone.categoryKey(category.id));
    await _isar.writeAsync((isar) {
      isar.categorys.put(category);
      isar.syncTombstones.delete(tombstoneId);
    });
    _events.add(CategoryUpserted(category, fromSync: fromSync));
  }

  /// 本地删除：仅当分类下没有日记时成功；行硬删 + 写同步墓碑。
  Future<bool> _deleteCategory(String id) async {
    final tombstone = SyncTombstone.forCategory(id, at: .timestamp());
    final deleted = await _isar.writeAsync((isar) {
      final hasDiary = !isar.diarys.where().categoryIdEqualTo(id).isEmpty();
      if (hasDiary) return false;
      if (isar.categorys.get(id) == null) return false;
      isar.categorys.delete(id);
      isar.syncTombstones.put(tombstone);
      return true;
    });
    if (deleted) _events.add(CategoryDeleted(id));
    return deleted;
  }
}
