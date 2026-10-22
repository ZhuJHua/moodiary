import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'db/database.dart';
import 'db/db_codec.dart';
import 'diary_repository.dart';

@lazySingleton
class PlaceRepository {
  PlaceRepository(this._db);

  final MoodiaryDatabase _db;

  final StreamController<PlaceEvent> _events =
      StreamController<PlaceEvent>.broadcast();

  Stream<PlaceEvent> get placeEvents => _events.stream;

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
      .insertOnConflictUpdate(
        TombstonesCompanion.insert(
          key: tombstone.key,
          timeMs: tombstone.timeMs,
          pushedBackendsJson: Value(dbStringList(tombstone.pushedBackends)),
        ),
      );

  /// 合并地点：保留 [kept]（可改名），删除 [removed] 并把指向它们的日记
  /// （含回收站）重指到保留地点。全部在一个事务内提交；
  /// [placeOrder] 为合并前的排序快照，调用方负责事后维护 KV 并展示撤销入口。
  ///
  /// 返回撤销凭据；[removed] 为空时抛 ArgumentError。
  Future<PlaceMergeRecord> mergePlaces({
    required Place kept,
    required String finalName,
    required List<Place> removed,
    required List<String> placeOrder,
    required DiaryRepository diaries,
  }) async {
    if (removed.isEmpty) {
      throw ArgumentError.value(removed, 'removed', '至少提供一个被合并的地点');
    }
    final now = DateTime.timestamp();
    late final Place keptBefore;
    late final List<Place> removedRows;
    late final List<Diary> affected;
    await _db.transaction(() async {
      final current = await getPlaceById(kept.id);
      if (current == null) {
        throw StateError('保留地点不存在：${kept.id}');
      }
      keptBefore = current;
      removedRows = await _getPlacesByIds([for (final p in removed) p.id]);
      if (removedRows.isEmpty) {
        throw StateError('被合并的地点均已不存在');
      }
      affected = await diaries.getDiariesWithPlaceIds([
        for (final p in removedRows) p.id,
      ]);
      await _db.into(
        _db.places,
      ).insertOnConflictUpdate(
        _toCompanion(
          current.copyWith(
            name: finalName.trim(),
            lastModified: now,
          ),
        ),
      );
      await diaries.repointDiaries(affected, kept.id, at: now);
      for (final place in removedRows) {
        await (_db.delete(
          _db.places,
        )..where((p) => p.id.equals(place.id))).go();
        await _insertTombstoneRow(SyncTombstone.forPlace(place.id, at: now));
      }
    });
    _events.add(
      PlaceUpserted(keptBefore.copyWith(name: finalName.trim(), lastModified: now)),
    );
    for (final place in removedRows) {
      _events.add(PlaceDeleted(place.id));
    }
    return PlaceMergeRecord(
      kept: keptBefore,
      removed: removedRows,
      diaryRemap: {for (final d in affected) d.id: d.placeId!},
      placeOrder: placeOrder,
    );
  }

  /// 撤销一次合并（[PlaceMergeRecord] 由 [mergePlaces] 返回）：
  /// 还原保留地点名称、原样插回被删地点并清掉其墓碑、把日记按凭据指回原地点。
  /// 全部在一个事务内提交；调用方负责事后还原排序 KV。
  Future<void> undoMerge(
    PlaceMergeRecord record, {
    required DiaryRepository diaries,
  }) async {
    final now = DateTime.timestamp();
    await _db.transaction(() async {
      final restoredKept = record.kept.copyWith(lastModified: now);
      await _db.into(
        _db.places,
      ).insertOnConflictUpdate(_toCompanion(restoredKept));
      final placeKeys = [
        for (final p in record.removed) SyncTombstone.placeKey(p.id),
      ];
      await (_db.delete(
        _db.tombstones,
      )..where((t) => t.key.isIn(placeKeys))).go();
      for (final place in record.removed) {
        await _db.into(
          _db.places,
        ).insertOnConflictUpdate(_toCompanion(place));
      }
      final affected = await diaries.getDiariesByIds(
        record.diaryRemap.keys.toList(),
      );
      final byId = {for (final d in affected) d.id: d};
      final grouped = <String, List<Diary>>{};
      for (final entry in record.diaryRemap.entries) {
        final diary = byId[entry.key];
        if (diary != null) {
          grouped.putIfAbsent(entry.value, () => []).add(diary);
        }
      }
      for (final entry in grouped.entries) {
        await diaries.repointDiaries(entry.value, entry.key, at: now);
      }
    });
    _events.add(PlaceUpserted(record.kept.copyWith(lastModified: now)));
    for (final place in record.removed) {
      _events.add(PlaceUpserted(place));
    }
  }

  Future<List<Place>> _getPlacesByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
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
