import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'db/database.dart';
import 'db/db_codec.dart';

/// 常用地点仓储。整体照 [CategoryRepository]：LWW by `lastModified` + 硬删写墓碑、
/// 有日记引用就不让删。日记通过 `placeId` 引用地点，改名 / 挪坐标全体日记跟着变。
@lazySingleton
class PlaceRepository {
  PlaceRepository(this._db);

  final MoodiaryDatabase _db;

  /// 单例随应用整个生命周期存活，故此 controller 不主动关闭。
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

  /// 按名字找（和风反查出来的行政区名会反复出现，同名复用而不是每篇建一个）。
  /// 两台设备各建过一个同名地点时取 id 最小的那个，稳定即可。
  Future<Place?> getPlaceByName(String name) async {
    final rows =
        await (_db.select(_db.places)
              ..where((p) => p.name.equals(name))
              ..orderBy([(p) => OrderingTerm.asc(p.id)])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : _toPlace(rows.first);
  }

  /// 全量地点（表内即全部活跃行，删除后行硬删、事实入墓碑表）。
  /// 排序交给上层——展示顺序存在 KV（`placeOrder`），不进表。
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

  /// [fromSync] = 该写入由活跃云后端的 pull 落库（远端已持有），事件携带此标记
  /// 供 AutoSyncWatcher 免除回声推送。
  Future<void> insertAPlace(Place place, {bool fromSync = false}) async {
    await _db.transaction(() async {
      await _db.into(_db.places).insertOnConflictUpdate(_toCompanion(place));
      // 复活闸门：同 id 的同步墓碑连带清除。
      await (_db.delete(
        _db.tombstones,
      )..where((t) => t.key.equals(SyncTombstone.placeKey(place.id)))).go();
    });
    _events.add(PlaceUpserted(place, fromSync: fromSync));
  }

  /// 本地删除：仅当没有日记引用、且行确实存在时成功；行硬删 + 写同步墓碑，三步同一
  /// 事务（同 [CategoryRepository.deleteACategory]）。行不在时**不写墓碑**——否则一枚
  /// 「此刻」的假墓碑会被推上去，把别的设备刚重建的同 id 地点删掉。
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

  /// 同步 pull 应用远端墓碑：远端说删就删，行在不在都记下墓碑（防复活）。
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
}

/// 两点间距离（米）。Haversine，地球半径取 IUGG 平均半径。
///
/// 自己算而不引 latlong2 的 `Distance()`：data 层为一个七行函数多背一个依赖不值当，
/// 而这个函数在「一次定位比对全部地点」的路径上要跑几十次。
double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371008.8;
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
  /// 坐标落在哪个地点里：[Place.matchRadius] 内、距离最小的那个；都不在返回 null。
  ///
  /// 靠得近的两个地点（同一栋楼的「公司」与「食堂」）会同时命中，取最近者；
  /// 新增地点时的重叠提示就是为了让用户先看见这件事。
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
