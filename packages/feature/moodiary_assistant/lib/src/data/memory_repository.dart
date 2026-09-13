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

  Future<List<MemoryEntry>> profileFacts({int limit = 6}) async {
    final rows =
        await (_db.select(_db.memories)
              ..where((m) => m.category.equals('preference'))
              ..orderBy([(m) => OrderingTerm.desc(m.updatedAt)])
              ..limit(limit))
            .get();
    return [for (final r in rows) _toEntry(r)];
  }

  Future<int> count() async {
    final q = _db.selectOnly(_db.memories)..addColumns([_db.memories.id.count()]);
    final row = await q.getSingle();
    return row.read(_db.memories.id.count()) ?? 0;
  }

  Future<List<MemoryEntry>> search(String query, {int limit = 8}) async {
    final all = await getAll();
    final terms = _terms(query);
    if (terms.isEmpty) return all.take(limit).toList();
    final scored = <(int, MemoryEntry)>[];
    for (final e in all) {
      final haystack = '${e.category} ${e.text}'.toLowerCase();
      var hits = 0;
      for (final t in terms) {
        if (haystack.contains(t)) hits++;
      }
      if (hits > 0) scored.add((hits, e));
    }
    if (scored.isEmpty) return const [];
    scored.sort((a, b) {
      final byHits = b.$1.compareTo(a.$1);
      return byHits != 0 ? byHits : b.$2.updatedAt.compareTo(a.$2.updatedAt);
    });
    return [for (final s in scored.take(limit)) s.$2];
  }

  static List<String> _terms(String query) {
    final lowered = query.toLowerCase();
    final out = <String>{};
    for (final w in lowered.split(RegExp(r'[^0-9a-z]+'))) {
      if (w.length > 1) out.add(w);
    }
    for (final rune in lowered.runes) {
      final ch = String.fromCharCode(rune);
      if (rune > 0x2E80) out.add(ch);
    }
    return out.toList();
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
