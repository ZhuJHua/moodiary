import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

class CategoryRepository {
  CategoryRepository._(this._isar);

  factory CategoryRepository.get() => _instance;

  @visibleForTesting
  CategoryRepository.forTesting(this._isar);

  static final CategoryRepository _instance = ._(IsarDatabase.get().isar);

  final Isar _isar;

  /// 单例随应用整个生命周期存活，故此 controller 不主动关闭。
  final StreamController<CategoryEvent> _events =
      StreamController<CategoryEvent>.broadcast();

  Stream<CategoryEvent> get categoryEvents => _events.stream;

  /// 全量分类（表内即全部活跃行，删除后行硬删、事实入 SyncTombstone 表）。
  /// 错误约定：失败直接抛（本包统一），调用方按需 catch 且至少 logger.e——
  /// 别把库故障吞成空列表。
  Future<List<Category>> getAllCategories() {
    return _isar.categorys.where().sortById().findAllAsync();
  }

  /// 按业务 id 取单个分类。
  Future<Category?> getCategoryById(String id) async {
    return await _isar.categorys.getAsync(id);
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

  // `_isar.writeAsync` 的回调会被送进后台 isolate 执行（Isar.run）：回调里只许
  // 引用局部数据参数，摸 `this` 的成员会连带捕获不可发送的 `_isar`，
  // 抛「object is unsendable」。
  /// [fromSync] = 该写入由活跃云后端的 pull 落库（远端已持有），事件携带此标记
  /// 供 AutoSyncWatcher 免除回声推送。
  Future<void> insertACategory(
    Category category, {
    bool fromSync = false,
  }) async {
    // 复活闸门：同 id 的同步墓碑连带清除（同步下载 / 重建同名 id 场景）。
    final tombstoneId = fastHash(SyncTombstone.categoryKey(category.id));
    await _isar.writeAsync((isar) {
      isar.categorys.put(category);
      isar.syncTombstones.delete(tombstoneId);
    });
    _events.add(CategoryUpserted(category, fromSync: fromSync));
  }

  /// 本地删除：仅当分类下没有日记时成功；行硬删 + 写同步墓碑。
  Future<bool> deleteACategory(String id) async {
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
