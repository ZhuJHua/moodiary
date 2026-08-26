
import 'dart:async';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

class MediaInfoRepository {
  MediaInfoRepository._(this._isar);

  factory MediaInfoRepository.get() => _instance;

  @visibleForTesting
  MediaInfoRepository.forTesting(this._isar);

  static final MediaInfoRepository _instance = ._(IsarDatabase.get().isar);

  final Isar _isar;

  /// 单例随应用整个生命周期存活，故此 controller 不主动关闭。
  final StreamController<MediaInfoEvent> _events =
      StreamController<MediaInfoEvent>.broadcast();

  Stream<MediaInfoEvent> get mediaInfoEvents => _events.stream;

  /// 全量媒体元数据（表内即全部活跃行，删除后行硬删、事实入 SyncTombstone 表）。
  /// 错误约定：失败直接抛（本包统一），调用方按需 catch 且至少 logger.e。
  Future<List<MediaInfo>> getAllMediaInfos() {
    return _isar.mediaInfos.where().sortByFileName().findAllAsync();
  }

  /// 按文件名（业务主键）取单行。
  Future<MediaInfo?> getMediaInfoByFileName(String fileName) async {
    return await _isar.mediaInfos.getAsync(fileName);
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

  // `_isar.writeAsync` 的回调会被送进后台 isolate 执行（Isar.run）：回调里只许
  // 引用局部数据参数，摸 `this` 的成员会连带捕获不可发送的 `_isar`，
  // 抛「object is unsendable」。
  /// [fromSync] = 该写入由活跃云后端的 pull 落库（远端已持有），事件携带此标记
  /// 供 AutoSyncWatcher 免除回声推送。
  Future<void> insertAMediaInfo(
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

  /// 本地删除（清理孤儿媒体时联动）：行硬删 + 写同步墓碑。
  Future<bool> deleteAMediaInfo(String fileName) async {
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
