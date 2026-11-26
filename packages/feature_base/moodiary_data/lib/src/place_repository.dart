import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'db/database.dart';
import 'db/db_codec.dart';
import 'diary_repository.dart';

class PlaceRepository {
  PlaceRepository(this._db, this._diaries);

  final MoodiaryDatabase _db;
  final DiaryRepository _diaries;

  final StreamController<PlaceEvent> _events =
      StreamController<PlaceEvent>.broadcast();

  Stream<PlaceEvent> get placeEvents => _events.stream;

  Future<void> dispose() => _events.close();

  static Place _toPlace(PlaceRow r) => Place(
    id: r.id,
    name: r.name,
    latitude: r.latitude,
    longitude: r.longitude,
    icon: r.icon,
    lastModified: dbToTime(r.lastModified),
  );

  static PlacesCompanion _toCompanion(Place p) => PlacesCompanion.insert(
    id: p.id,
    name: p.name,
    latitude: p.latitude,
    longitude: p.longitude,
    icon: Value(p.icon),
    lastModified: dbTime(p.lastModified),
  );

  Future<Place?> getPlaceByName(String name) async {
    final rows =
        await (_db.select(_db.places)
              ..where((p) => p.name.equals(name))
              ..orderBy([(p) => OrderingTerm.asc(p.id)])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : _toPlace(rows.first);
  }

  Future<List<Place>> getAllPlaces() async {
    final rows = await (_db.select(
      _db.places,
    )..orderBy([(p) => OrderingTerm.asc(p.id)])).get();
    return [for (final r in rows) _toPlace(r)];
  }

  Future<Place?> getPlaceById(String id) async {
    final row = await (_db.select(
      _db.places,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toPlace(row);
  }

  Future<void> insertAPlace(Place place, {bool fromSync = false}) async {
    await _db.transaction(() async {
      await _db.into(_db.places).insertOnConflictUpdate(_toCompanion(place));
      await (_db.delete(
        _db.tombstones,
      )..where((t) => t.key.equals(SyncTombstone.placeKey(place.id)))).go();
    });
    _events.add(PlaceUpserted(place, fromSync: fromSync));
  }

  Future<bool> deleteAPlace(String id) async {
    final tombstone = SyncTombstone.forPlace(id, at: .timestamp());
    final deleted = await _db.transaction(() async {
      final referenced =
          await (_db.select(_db.diaries)
                ..where((d) => d.placeId.equals(id))
                ..limit(1))
              .getSingleOrNull() !=
          null;
      if (referenced) return false;
      final removed = await (_db.delete(
        _db.places,
      )..where((p) => p.id.equals(id))).go();
      if (removed == 0) return false;
      await _insertTombstoneRow(tombstone);
      return true;
    });
    if (deleted) _events.add(PlaceDeleted(id));
    return deleted;
  }

  Future<SyncTombstone> tombstonePlaceForSync(
    String id, {
    bool fromSync = false,
  }) async {
    final tombstone = SyncTombstone.forPlace(id, at: .timestamp());
    await _db.transaction(() async {
      await (_db.delete(_db.places)..where((p) => p.id.equals(id))).go();
      await _insertTombstoneRow(tombstone);
    });
    _events.add(PlaceDeleted(id, fromSync: fromSync));
    return tombstone;
  }

  Future<void> _insertTombstoneRow(SyncTombstone tombstone) => _db
      .into(_db.tombstones)
      .insertOnConflictUpdate(_tombstoneCompanion(tombstone));

  TombstonesCompanion _tombstoneCompanion(SyncTombstone tombstone) =>
      TombstonesCompanion.insert(
        key: tombstone.key,
        timeMs: tombstone.timeMs,
        pushedBackendsJson: Value(dbStringList(tombstone.pushedBackends)),
      );

  Future<PlaceMergeRecord> mergePlaces({
    required String keptId,
    required List<String> removedIds,
    required String finalName,
  }) async {
    final now = DateTime.timestamp();
    final result = await _db.transaction(() async {
      final places = await _getPlacesByIds([keptId, ...removedIds]);
      final kept = places.where((place) => place.id == keptId).firstOrNull;
      if (kept == null) throw StateError('保留地点不存在：$keptId');
      final removed = places.where((place) => place.id != keptId).toList();
      if (removed.isEmpty) throw StateError('被合并的地点均已不存在');
      final ids = [for (final place in removed) place.id];
      final affected = await _diaries.getDiariesWithPlaceIds(ids);
      final renamed = kept.copyWith(name: finalName.trim(), lastModified: now);
      await _db.into(_db.places).insertOnConflictUpdate(_toCompanion(renamed));
      final repointed = await _diaries.repointDiaries(
        affected,
        keptId,
        at: now,
      );
      await (_db.delete(_db.places)..where((place) => place.id.isIn(ids))).go();
      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(_db.tombstones, [
          for (final place in removed)
            _tombstoneCompanion(SyncTombstone.forPlace(place.id, at: now)),
        ]);
      });
      return (
        renamed: renamed,
        repointed: repointed,
        record: PlaceMergeRecord(
          kept: kept,
          removed: removed,
          diaryRemap: {for (final diary in affected) diary.id: diary.placeId!},
        ),
      );
    });
    _diaries.publishDiaryUpdates(result.repointed);
    _events.add(PlaceUpserted(result.renamed));
    for (final place in result.record.removed) {
      _events.add(PlaceDeleted(place.id));
    }
    return result.record;
  }

  Future<void> undoMerge(PlaceMergeRecord record) async {
    final now = DateTime.timestamp();
    // 时间戳必须晚于合并墓碑，才能同步复活地点。
    final restored = [
      for (final place in [record.kept, ...record.removed])
        place.copyWith(lastModified: now),
    ];
    final repointed = await _db.transaction(() async {
      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(_db.places, [
          for (final place in restored) _toCompanion(place),
        ]);
      });
      final placeKeys = [
        for (final place in record.removed) SyncTombstone.placeKey(place.id),
      ];
      await (_db.delete(
        _db.tombstones,
      )..where((t) => t.key.isIn(placeKeys))).go();
      final affected = await _diaries.getDiariesByIds(
        record.diaryRemap.keys.toList(),
      );
      final grouped = <String, List<Diary>>{};
      for (final diary in affected) {
        grouped.putIfAbsent(record.diaryRemap[diary.id]!, () => []).add(diary);
      }
      final updated = <Diary>[];
      for (final entry in grouped.entries) {
        updated.addAll(
          await _diaries.repointDiaries(entry.value, entry.key, at: now),
        );
      }
      return updated;
    });
    _diaries.publishDiaryUpdates(repointed);
    for (final place in restored) {
      _events.add(PlaceUpserted(place));
    }
  }

  Future<List<Place>> _getPlacesByIds(List<String> ids) async {
    final rows = await (_db.select(
      _db.places,
    )..where((p) => p.id.isIn(ids))).get();
    return [for (final r in rows) _toPlace(r)];
  }
}

double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371008.8; // IUGG 地球平均半径（米）
  const toRad = math.pi / 180;
  final dLat = (lat2 - lat1) * toRad;
  final dLon = (lon2 - lon1) * toRad;
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * toRad) *
          math.cos(lat2 * toRad) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return 2 * earthRadius * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

extension PlaceMatching on List<Place> {
  Place? matchAt(double latitude, double longitude) {
    Place? best;
    var bestDistance = double.infinity;
    for (final place in this) {
      final d = distanceMeters(
        latitude,
        longitude,
        place.latitude,
        place.longitude,
      );
      if (d <= Place.matchRadius && d < bestDistance) {
        best = place;
        bestDistance = d;
      }
    }
    return best;
  }
}
