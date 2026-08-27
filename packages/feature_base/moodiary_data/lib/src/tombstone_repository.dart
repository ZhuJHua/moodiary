import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:moodiary_models/moodiary_models.dart';

import 'db/database.dart';
import 'db/db_codec.dart';

/// 同步墓碑仓储。行由 [DiaryRepository] / [CategoryRepository] 在各自的删除 /
/// 复活事务内写入与清除；本仓储负责同步引擎的读取与推送记录回写，以及启动 GC。
class TombstoneRepository {
  TombstoneRepository._(this._db);

  factory TombstoneRepository.get() => _instance;

  @visibleForTesting
  TombstoneRepository.forTesting(this._db);

  static final TombstoneRepository _instance = ._(MoodiaryDatabase.get());

  final MoodiaryDatabase _db;

  /// 墓碑保留窗：窗内足够让云后端 / 局域网 / 备份把删除传播出去；超窗由启动 GC
  /// 清除，接受「更陈旧的备份导入会复活该日记」的权衡（删除本身也已无从传播）。
  static const Duration defaultRetention = Duration(days: 90);

  static SyncTombstone _toTombstone(TombstoneRow r) => SyncTombstone(
    key: r.key,
    timeMs: r.timeMs,
    pushedBackends: dbToStringList(r.pushedBackendsJson),
  );

  Future<List<SyncTombstone>> getAll() async {
    final rows = await _db.select(_db.tombstones).get();
    return [for (final r in rows) _toTombstone(r)];
  }

  Future<SyncTombstone?> getByKey(String key) async {
    final row = await (_db.select(
      _db.tombstones,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row == null ? null : _toTombstone(row);
  }

  /// 引擎批量回写推送记录（一次同步内内存增量改、结尾落一次库）。
  Future<void> putAll(List<SyncTombstone> rows) async {
    if (rows.isEmpty) return;
    await _db.batch((b) {
      b.insertAllOnConflictUpdate(_db.tombstones, [
        for (final t in rows)
          TombstonesCompanion.insert(
            key: t.key,
            timeMs: t.timeMs,
            pushedBackendsJson: Value(dbStringList(t.pushedBackends)),
          ),
      ]);
    });
  }

  /// 引擎确认「全部已配置云后端均已覆盖」后清除墓碑行。
  Future<void> deleteByKeys(List<String> keys) async {
    if (keys.isEmpty) return;
    await (_db.delete(_db.tombstones)..where((t) => t.key.isIn(keys))).go();
  }

  /// 启动 GC：清除超过保留窗的墓碑，返回清除条数。不看后端覆盖情况——保留窗
  /// 是删除传播的时限上限，零后端用户的墓碑因此有界。
  Future<int> purgeExpired({
    Duration retention = defaultRetention,
    DateTime? now,
  }) async {
    final cutoff = (now ?? .timestamp())
        .subtract(retention)
        .millisecondsSinceEpoch;
    return (_db.delete(
      _db.tombstones,
    )..where((t) => t.timeMs.isSmallerThanValue(cutoff))).go();
  }
}
