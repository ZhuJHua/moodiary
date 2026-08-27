import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

/// 助手长期记忆（[MemoryEntry]）的读写。仅设备本地：不进 local_archive 备份、不进 LAN 同步。
class MemoryRepository {
  MemoryRepository._(this._db);

  factory MemoryRepository.get() => _instance;

  @visibleForTesting
  MemoryRepository.forTesting(this._db);

  static final MemoryRepository _instance = ._(MoodiaryDatabase.get());

  final MoodiaryDatabase _db;

  static MemoryEntry _toEntry(MemoryRow r) => MemoryEntry(
    id: r.id,
    category: r.category,
    text: r.content,
    createdAt: dbToTime(r.createdAt),
    updatedAt: dbToTime(r.updatedAt),
  );

  /// 全部记忆，按更新时间倒序（最近的在前）。
  Future<List<MemoryEntry>> getAll() async {
    final rows = await (_db.select(
      _db.memories,
    )..orderBy([(m) => OrderingTerm.desc(m.updatedAt)])).get();
    return [for (final r in rows) _toEntry(r)];
  }

  /// 最近更新的前 [limit] 条，用于每轮注入（避免注入全部撑爆上下文）。
  Future<List<MemoryEntry>> getRecent(int limit) async {
    final rows =
        await (_db.select(_db.memories)
              ..orderBy([(m) => OrderingTerm.desc(m.updatedAt)])
              ..limit(limit))
            .get();
    return [for (final r in rows) _toEntry(r)];
  }

  Future<MemoryEntry?> get(String id) async {
    final row = await (_db.select(
      _db.memories,
    )..where((m) => m.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toEntry(row);
  }

  Future<void> put(MemoryEntry entry) async {
    await _db
        .into(_db.memories)
        .insertOnConflictUpdate(
          MemoriesCompanion.insert(
            id: entry.id,
            category: entry.category,
            content: entry.text,
            createdAt: dbTime(entry.createdAt),
            updatedAt: dbTime(entry.updatedAt),
          ),
        );
  }

  Future<bool> delete(String id) async {
    final removed = await (_db.delete(
      _db.memories,
    )..where((m) => m.id.equals(id))).go();
    return removed > 0;
  }
}
