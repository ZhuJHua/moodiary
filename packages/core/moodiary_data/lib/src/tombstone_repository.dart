import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

/// 同步墓碑仓储。行由 [DiaryRepository] / [CategoryRepository] 在各自的删除 /
/// 复活事务内写入与清除；本仓储负责同步引擎的读取与推送记录回写，以及启动 GC。
class TombstoneRepository {
  TombstoneRepository._(this._isar);

  factory TombstoneRepository.get() => _instance;

  @visibleForTesting
  TombstoneRepository.forTesting(this._isar);

  static final TombstoneRepository _instance = ._(IsarDatabase.get().isar);

  final Isar _isar;

  /// 墓碑保留窗：窗内足够让云后端 / 局域网 / 备份把删除传播出去；超窗由启动 GC
  /// 清除，接受「更陈旧的备份导入会复活该日记」的权衡（删除本身也已无从传播）。
  static const Duration defaultRetention = Duration(days: 90);

  Future<List<SyncTombstone>> getAll() =>
      _isar.syncTombstones.where().findAllAsync();

  Future<SyncTombstone?> getByKey(String key) =>
      _isar.syncTombstones.getAsync(fastHash(key));

  /// 引擎批量回写推送记录（一次同步内内存增量改、结尾落一次库）。
  Future<void> putAll(List<SyncTombstone> rows) async {
    if (rows.isEmpty) return;
    await _isar.writeAsync((isar) {
      isar.syncTombstones.putAll(rows);
    });
  }

  /// 引擎确认「全部已配置云后端均已覆盖」后清除墓碑行。
  Future<void> deleteByKeys(List<String> keys) async {
    if (keys.isEmpty) return;
    final ids = [for (final key in keys) fastHash(key)];
    await _isar.writeAsync((isar) {
      isar.syncTombstones.deleteAll(ids);
    });
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
    final expired = await _isar.syncTombstones
        .where()
        .timeMsLessThan(cutoff)
        .findAllAsync();
    if (expired.isEmpty) return 0;
    final ids = [for (final t in expired) t.isarId];
    await _isar.writeAsync((isar) {
      isar.syncTombstones.deleteAll(ids);
    });
    return expired.length;
  }
}
