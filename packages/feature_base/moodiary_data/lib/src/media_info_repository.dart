import 'dart:async';

import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'db/database.dart';
import 'db/db_codec.dart';

@lazySingleton
class MediaInfoRepository {
  MediaInfoRepository(this._db);

  final MoodiaryDatabase _db;

  final StreamController<MediaInfoEvent> _events =
      StreamController<MediaInfoEvent>.broadcast();

  Stream<MediaInfoEvent> get mediaInfoEvents => _events.stream;

  static MediaInfo _toMediaInfo(MediaInfoRow r) => MediaInfo(
    fileName: r.fileName,
    name: r.name,
    durationMs: r.durationMs,
    lastModified: dbToTime(r.lastModified),
  );

  Future<List<MediaInfo>> getAllMediaInfos() async {
    final rows = await (_db.select(
      _db.mediaInfos,
    )..orderBy([(m) => OrderingTerm.asc(m.fileName)])).get();
    return [for (final r in rows) _toMediaInfo(r)];
  }

  Future<MediaInfo?> getMediaInfoByFileName(String fileName) async {
    final row = await (_db.select(
      _db.mediaInfos,
    )..where((m) => m.fileName.equals(fileName))).getSingleOrNull();
    return row == null ? null : _toMediaInfo(row);
  }

  Future<SyncTombstone> tombstoneMediaInfoForSync(
    String fileName, {
    bool fromSync = false,
  }) async {
    final tombstone = SyncTombstone.forMediaInfo(fileName, at: .timestamp());
    await _db.transaction(() async {
      await (_db.delete(
        _db.mediaInfos,
      )..where((m) => m.fileName.equals(fileName))).go();
      await _db
          .into(_db.tombstones)
          .insertOnConflictUpdate(
            TombstonesCompanion.insert(
              key: tombstone.key,
              timeMs: tombstone.timeMs,
              pushedBackendsJson: Value(dbStringList(tombstone.pushedBackends)),
            ),
          );
    });
    _events.add(MediaInfoDeleted(fileName, fromSync: fromSync));
    return tombstone;
  }

  Future<void> insertAMediaInfo(
    MediaInfo mediaInfo, {
    bool fromSync = false,
  }) async {
    await _db.transaction(() async {
      await _db
          .into(_db.mediaInfos)
          .insertOnConflictUpdate(
            MediaInfosCompanion.insert(
              fileName: mediaInfo.fileName,
              name: Value(mediaInfo.name),
              durationMs: Value(mediaInfo.durationMs),
              lastModified: dbTime(mediaInfo.lastModified),
            ),
          );
      await (_db.delete(_db.tombstones)..where(
            (t) => t.key.equals(SyncTombstone.mediaInfoKey(mediaInfo.fileName)),
          ))
          .go();
    });
    _events.add(MediaInfoUpserted(mediaInfo, fromSync: fromSync));
  }

  Future<bool> deleteAMediaInfo(String fileName) async {
    final tombstone = SyncTombstone.forMediaInfo(fileName, at: .timestamp());
    final deleted = await _db.transaction(() async {
      final removed = await (_db.delete(
        _db.mediaInfos,
      )..where((m) => m.fileName.equals(fileName))).go();
      if (removed == 0) return false;
      await _db
          .into(_db.tombstones)
          .insertOnConflictUpdate(
            TombstonesCompanion.insert(
              key: tombstone.key,
              timeMs: tombstone.timeMs,
              pushedBackendsJson: Value(dbStringList(tombstone.pushedBackends)),
            ),
          );
      return true;
    });
    if (deleted) _events.add(MediaInfoDeleted(fileName));
    return deleted;
  }
}
