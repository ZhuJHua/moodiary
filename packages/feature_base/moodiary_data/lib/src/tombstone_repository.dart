import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'db/database.dart';
import 'db/db_codec.dart';

@lazySingleton
class TombstoneRepository {
  TombstoneRepository(this._db);

  final MoodiaryDatabase _db;

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

  Future<void> deleteByKeys(List<String> keys) async {
    if (keys.isEmpty) return;
    await (_db.delete(_db.tombstones)..where((t) => t.key.isIn(keys))).go();
  }

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
