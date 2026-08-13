import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

class MediaInfoRepository {
  MediaInfoRepository._(this._isar);

  factory MediaInfoRepository.get() => _instance;

  static final MediaInfoRepository _instance = ._(IsarDatabase.get().isar);

  final Isar _isar;

  /// 单例随应用整个生命周期存活，故此 controller 不主动关闭。
  final StreamController<MediaInfoEvent> _events =
      StreamController<MediaInfoEvent>.broadcast();

  Stream<MediaInfoEvent> get mediaInfoEvents => _events.stream;

  /// 全量媒体元数据（表内即全部活跃行，删除后行硬删、事实入 SyncTombstone 表）。
  TaskEither<DatabaseException, List<MediaInfo>> getAllMediaInfos() {
    return .tryCatch(
      () async =>
          await _isar.mediaInfos.where().sortByFileName().findAllAsync(),
      (e, _) => DatabaseException('Failed to fetch media infos: $e'),
    );
  }

  TaskEither<DatabaseException, List<MediaInfo>> getAllMediaInfosForSync() =>
      getAllMediaInfos();

  /// 按文件名（业务主键）取单行。
  Future<MediaInfo?> getMediaInfoByFileName(String fileName) async {
    return await _isar.mediaInfos.getAsync(fileName);
  }

  /// [fromSync] = 该写入由活跃云后端的 pull 落库（远端已持有），事件携带此标记
  /// 供 AutoSyncWatcher 免除回声推送。
  TaskEither<DatabaseException, void> insertAMediaInfo(
    MediaInfo mediaInfo, {
    bool fromSync = false,
  }) {
    return .tryCatch(
      () => _putMediaInfo(mediaInfo, fromSync: fromSync),
      (e, _) => DatabaseException('Failed to insert media info: $e'),
    );
  }

  /// 本地删除（清理孤儿媒体时联动）：行硬删 + 写同步墓碑。
  TaskEither<DatabaseException, bool> deleteAMediaInfo(String fileName) {
    return .tryCatch(
      () => _deleteMediaInfo(fileName),
      (e, _) => DatabaseException('Failed to delete media info: $e'),
    );
  }

  /// 同步 pull 应用远端媒体元数据墓碑：行硬删 + 写墓碑。返回写入的墓碑行。
  /// [fromSync] 语义同 [insertAMediaInfo]。
  Future<SyncTombstone> tombstoneMediaInfoForSync(
    String fileName, {
    bool fromSync = false,
  }) async {
    final tombstone = SyncTombstone.forMediaInfo(fileName, at: .timestamp());
    await _isar.writeAsync((isar) {
      isar.mediaInfos.delete(fileName);
      isar.syncTombstones.put(tombstone);
    });
    _events.add(MediaInfoDeleted(fileName, fromSync: fromSync));
    return tombstone;
  }

  // 写操作抽成独立方法（而非直接放进 TaskEither 的闭包里）：`_isar.writeAsync` 的回调会被
  // 送进后台 isolate 执行（Isar.run），若回调嵌在会捕获 `this` 的闭包里，就会连带捕获不可
  // 发送的 `_isar`，抛「object is unsendable」。独立方法里的回调只捕获数据参数（可发送）。
  Future<void> _putMediaInfo(
    MediaInfo mediaInfo, {
    bool fromSync = false,
  }) async {
    // 复活闸门：同 key 的同步墓碑连带清除（同步下载 / 重建同名文件场景）。
    final tombstoneId = fastHash(
      SyncTombstone.mediaInfoKey(mediaInfo.fileName),
    );
    await _isar.writeAsync((isar) {
      isar.mediaInfos.put(mediaInfo);
      isar.syncTombstones.delete(tombstoneId);
    });
    _events.add(MediaInfoUpserted(mediaInfo, fromSync: fromSync));
  }

  Future<bool> _deleteMediaInfo(String fileName) async {
    final tombstone = SyncTombstone.forMediaInfo(fileName, at: .timestamp());
    final deleted = await _isar.writeAsync((isar) {
      if (isar.mediaInfos.get(fileName) == null) return false;
      isar.mediaInfos.delete(fileName);
      isar.syncTombstones.put(tombstone);
      return true;
    });
    if (deleted) _events.add(MediaInfoDeleted(fileName));
    return deleted;
  }
}
