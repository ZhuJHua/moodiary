import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';

/// 助手长期记忆（[MemoryEntry]）的读写。仅设备本地：不进 local_archive 备份、不进 LAN 同步。
class MemoryRepository {
  MemoryRepository._(this._isar);

  factory MemoryRepository.get() => _instance;

  static final MemoryRepository _instance = MemoryRepository._(
    IsarDatabase.get().isar,
  );

  final Isar _isar;

  /// 全部记忆，按更新时间倒序（最近的在前）。
  Future<List<MemoryEntry>> getAll() {
    return _isar.memories.where().sortByUpdatedAtDesc().findAllAsync();
  }

  /// 最近更新的前 [limit] 条，用于每轮注入（避免注入全部撑爆上下文）。
  Future<List<MemoryEntry>> getRecent(int limit) {
    return _isar.memories.where().sortByUpdatedAtDesc().findAllAsync(
      limit: limit,
    );
  }

  Future<MemoryEntry?> get(String id) => _isar.memories.getAsync(id);

  Future<void> put(MemoryEntry entry) async {
    await _isar.writeAsync((isar) {
      isar.memories.put(entry);
    });
  }

  Future<bool> delete(String id) {
    return _isar.writeAsync((isar) {
      return isar.memories.delete(id);
    });
  }
}
