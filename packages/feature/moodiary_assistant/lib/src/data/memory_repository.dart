import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

@lazySingleton
class MemoryRepository {
  MemoryRepository(this._db);

  final MoodiaryDatabase _db;

  static MemoryEntry _toEntry(MemoryRow r) => MemoryEntry(
    id: r.id,
    category: r.category,
    text: r.content,
    createdAt: dbToTime(r.createdAt),
    updatedAt: dbToTime(r.updatedAt),
  );

  Future<List<MemoryEntry>> getAll() async {
    final rows = await (_db.select(
      _db.memories,
    )..orderBy([(m) => OrderingTerm.desc(m.updatedAt)])).get();
    return [for (final r in rows) _toEntry(r)];
  }

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
