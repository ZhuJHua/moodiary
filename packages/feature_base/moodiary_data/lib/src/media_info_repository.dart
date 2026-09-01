import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:moodiary_models/moodiary_models.dart';

import 'db/database.dart';
import 'db/db_codec.dart';

class MediaInfoRepository {
  MediaInfoRepository._(this._db);

  factory MediaInfoRepository.get() => _instance;

  @visibleForTesting
  MediaInfoRepository.forTesting(this._db);

  static final MediaInfoRepository _instance = ._(MoodiaryDatabase.get());

  final MoodiaryDatabase _db;

  /// 单例随应用整个生命周期存活，故此 controller 不主动关闭。
  final StreamController<MediaInfoEvent> _events =
      StreamController<MediaInfoEvent>.broadcast();

  Stream<MediaInfoEvent> get mediaInfoEvents => _events.stream;

  static MediaInfo _toMediaInfo(MediaInfoRow r) => MediaInfo(
    fileName: r.fileName,
    name: r.name,
    durationMs: r.durationMs,
    lastModified: dbToTime(r.lastModified),
  );

  /// 全量媒体元数据（表内即全部活跃行，删除后行硬删、事实入墓碑表）。
  /// 错误约定：失败直接抛（本包统一），调用方按需 catch 且至少 logger.e。
  Future<List<MediaInfo>> getAllMediaInfos() async {
    final rows = await (_db.select(
      _db.mediaInfos,
    )..orderBy([(m) => OrderingTerm.asc(m.fileName)])).get();
    return [for (final r in rows) _toMediaInfo(r)];
  }

  /// 按文件名（主键）取单行。
  Future<MediaInfo?> getMediaInfoByFileName(String fileName) async {
    final row = await (_db.select(
      _db.mediaInfos,
    )..where((m) => m.fileName.equals(fileName))).getSingleOrNull();
    return row == null ? null : _toMediaInfo(row);
  }

  /// 同步 pull 应用远端媒体元数据墓碑：行硬删 + 写墓碑。返回写入的墓碑行。
  /// [fromSync] 语义同 [insertAMediaInfo]。
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

  /// [fromSync] = 该写入由活跃云后端的 pull 落库（远端已持有），事件携带此标记
  /// 供 AutoSyncWatcher 免除回声推送。
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
      // 复活闸门：同 key 的同步墓碑连带清除（同步下载 / 重建同名文件场景）。
      await (_db.delete(_db.tombstones)..where(
            (t) => t.key.equals(SyncTombstone.mediaInfoKey(mediaInfo.fileName)),
          ))
          .go();
    });
    _events.add(MediaInfoUpserted(mediaInfo, fromSync: fromSync));
  }

  /// 本地删除（清理孤儿媒体时联动）：行硬删 + 写同步墓碑。
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
