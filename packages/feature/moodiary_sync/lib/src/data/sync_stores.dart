import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_sync/src/data/media_refs.dart';
import 'package:moodiary_sync/src/data/sync_cancellation.dart';
import 'package:path/path.dart' as p;

/// 引擎对本地存储的最小依赖面，抽成端口以便单测注入内存假实现 —— 生产实现
/// （[RepoSyncDiaryStore] / [RepoSyncCategoryStore] / [DiskSyncMediaFiles]）只是
/// 转发到现有 repository / AppFiles，行为与重构前完全一致。
abstract interface class SyncDiaryStore {
  /// 全量活跃日记（含回收站；已删日记的行已硬删、事实在墓碑表）。
  Future<List<Diary>> getAllDiaries();
  Future<Diary?> getDiaryByBusinessId(String id);

  /// 落库并连带清除同 id 的墓碑行（复活闸门）。[fromSync] = 来源为活跃云后端
  /// 的 pull（远端已持有），领域事件携带此标记以免除回声推送。
  /// [deferIndex] = 只入重索引队列不当场分词（批量 pull 用，见 [settleIndexes]）。
  Future<void> insertADiary(
    Diary diary, {
    bool fromSync = false,
    bool deferIndex = false,
  });

  /// 把 defer 出的重索引账结清。工作量自己量（读队列长度），不靠调用方传
  /// 计数——engine 的 diaryChanged 把墓碑删除也算在内（那条路不产生队列行），
  /// 曾把「对端清理 300 篇」误判成要整库重建。幂等；被取消 / 崩溃后启动维护
  /// 兜底排空。
  Future<void> settleIndexes();

  /// pull 应用远端墓碑：行硬删 + 写墓碑（媒体由引擎媒体端口清理），返回墓碑行。
  Future<SyncTombstone> tombstoneDiary(Diary diary, {bool fromSync = false});
}

abstract interface class SyncCategoryStore {
  /// 全量分类快照（同步用）。
  Future<List<Category>> getAllCategoriesForSync();
  Future<Category?> getCategoryById(String id);

  /// 写入成功返回 `true`；落库并连带清除同 id 的墓碑行（复活闸门）。
  Future<bool> insertACategory(Category category, {bool fromSync = false});

  /// pull 应用远端分类墓碑：行硬删 + 写墓碑，返回墓碑行。
  Future<SyncTombstone> tombstoneCategory(String id, {bool fromSync = false});
}

abstract interface class SyncMediaInfoStore {
  /// 全量媒体元数据快照（同步用）。
  Future<List<MediaInfo>> getAllMediaInfosForSync();
  Future<MediaInfo?> getMediaInfoByFileName(String fileName);

  /// 写入成功返回 `true`；落库并连带清除同 key 的墓碑行（复活闸门）。
  Future<bool> insertAMediaInfo(MediaInfo mediaInfo, {bool fromSync = false});

  /// pull 应用远端媒体元数据墓碑：行硬删 + 写墓碑，返回墓碑行。
  Future<SyncTombstone> tombstoneMediaInfo(
    String fileName, {
    bool fromSync = false,
  });
}

/// 同步墓碑表端口：引擎读取全量、批量回写推送记录、清除已覆盖的行。
abstract interface class SyncTombstoneStore {
  Future<List<SyncTombstone>> getAll();
  Future<SyncTombstone?> getByKey(String key);
  Future<void> putAll(List<SyncTombstone> rows);
  Future<void> deleteByKeys(List<String> keys);
}

/// 本地媒体文件读写（按 `type`/`filename` 寻址，[type] 为 image/audio/video）。
abstract interface class SyncMediaFiles {
  Future<bool> exists(String type, String filename);
  Future<Uint8List> read(String type, String filename);
  Future<void> write(String type, String filename, Uint8List bytes);
  Future<void> delete(String type, String filename);

  /// 真实磁盘路径，供 Rust 直接读写；内存文件系统等 Rust 看不见的实现返回 null，
  /// 调用方退回字节路径。
  String? realPath(String type, String filename);

  /// 用新日记替换旧日记后，删除不再被引用的旧媒体（含视频缩略图）。
  Future<void> cleanUpReplaced(Diary oldDiary, Diary newDiary);
}

class RepoSyncDiaryStore implements SyncDiaryStore {
  final DiaryRepository _repo = .get();

  @override
  Future<List<Diary>> getAllDiaries() => _repo.getAllDiaries();

  @override
  Future<Diary?> getDiaryByBusinessId(String id) =>
      _repo.getDiaryByBusinessId(id);

  @override
  Future<void> insertADiary(
    Diary diary, {
    bool fromSync = false,
    bool deferIndex = false,
  }) => _repo.insertADiary(
    diary,
    fromSync: fromSync,
    index: deferIndex ? .defer : .inline,
  );

  /// 绝对下限 200 + 相对阈值 30%：小账排空（每篇一次分词+一次事务）；只有
  /// 账多到接近换机恢复量级（且占了库的三成以上）才值得整库重建——2 万篇的库
  /// 拉到 201 篇更新不该被拖去全量重分词。
  static const int _rebuildThreshold = 200;

  @override
  Future<void> settleIndexes() async {
    final pending = await _repo.reindexQueueLength();
    if (pending == 0) return;
    // 用户点了「停止」就别再拖一轮不可中断的重建/排空——账留给启动维护兜底。
    if (SyncCancellation.instance.isRequested) return;
    final total = await _repo.diaryRowCount();
    if (pending > _rebuildThreshold && pending > total * 0.3) {
      await _repo.rebuildAllIndexes();
    } else {
      await _repo.drainReindexQueue();
    }
  }

  @override
  Future<SyncTombstone> tombstoneDiary(Diary diary, {bool fromSync = false}) =>
      _repo.tombstoneDiaryForSync(diary, fromSync: fromSync);
}

class RepoSyncCategoryStore implements SyncCategoryStore {
  final CategoryRepository _repo = .get();

  @override
  Future<List<Category>> getAllCategoriesForSync() => _repo.getAllCategories();

  @override
  Future<Category?> getCategoryById(String id) => _repo.getCategoryById(id);

  @override
  Future<bool> insertACategory(
    Category category, {
    bool fromSync = false,
  }) async {
    await _repo.insertACategory(category, fromSync: fromSync);
    return true;
  }

  @override
  Future<SyncTombstone> tombstoneCategory(String id, {bool fromSync = false}) =>
      _repo.tombstoneCategoryForSync(id, fromSync: fromSync);
}

class RepoSyncMediaInfoStore implements SyncMediaInfoStore {
  final MediaInfoRepository _repo = .get();

  @override
  Future<List<MediaInfo>> getAllMediaInfosForSync() => _repo.getAllMediaInfos();

  @override
  Future<MediaInfo?> getMediaInfoByFileName(String fileName) =>
      _repo.getMediaInfoByFileName(fileName);

  @override
  Future<bool> insertAMediaInfo(
    MediaInfo mediaInfo, {
    bool fromSync = false,
  }) async {
    await _repo.insertAMediaInfo(mediaInfo, fromSync: fromSync);
    return true;
  }

  @override
  Future<SyncTombstone> tombstoneMediaInfo(
    String fileName, {
    bool fromSync = false,
  }) => _repo.tombstoneMediaInfoForSync(fileName, fromSync: fromSync);
}

class RepoSyncTombstoneStore implements SyncTombstoneStore {
  final TombstoneRepository _repo = .get();

  @override
  Future<List<SyncTombstone>> getAll() => _repo.getAll();

  @override
  Future<SyncTombstone?> getByKey(String key) => _repo.getByKey(key);

  @override
  Future<void> putAll(List<SyncTombstone> rows) => _repo.putAll(rows);

  @override
  Future<void> deleteByKeys(List<String> keys) => _repo.deleteByKeys(keys);
}

/// 生产媒体实现：默认 [LocalFileSystem]（行为同 `dart:io`），布局
/// `<baseDir>/<type>/<filename>`，与 `AppFiles.getRealPath` 一致。注入
/// `package:file` 的 `MemoryFileSystem` + 自定义 [baseDir] 即可纯内存单测。
class DiskSyncMediaFiles implements SyncMediaFiles {
  DiskSyncMediaFiles({FileSystem? fileSystem, String? baseDir})
    : _fs = fileSystem ?? const LocalFileSystem(),
      _baseDir = baseDir ?? PlatformService.get().applicationSupportPath;

  final FileSystem _fs;
  final String _baseDir;

  File _file(String type, String filename) =>
      _fs.file(p.join(_baseDir, type, filename));

  @override
  Future<bool> exists(String type, String filename) =>
      _file(type, filename).exists();

  @override
  Future<Uint8List> read(String type, String filename) =>
      _file(type, filename).readAsBytes();

  @override
  String? realPath(String type, String filename) =>
      _fs is LocalFileSystem ? _file(type, filename).path : null;

  @override
  Future<void> write(String type, String filename, Uint8List bytes) async {
    final file = _file(type, filename);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  }

  @override
  Future<void> delete(String type, String filename) async {
    final file = _file(type, filename);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> cleanUpReplaced(Diary oldDiary, Diary newDiary) async {
    Future<void> drop(
      List<String> oldNames,
      List<String> newNames,
      String type,
    ) async {
      for (final name in oldNames) {
        if (!newNames.contains(name)) await delete(type, name);
      }
    }

    await drop(oldDiary.imageName, newDiary.imageName, 'image');
    await drop(oldDiary.audioName, newDiary.audioName, 'audio');
    await drop(oldDiary.videoName, newDiary.videoName, 'video');
    // 被移除的视频连带删其缩略图（与视频同目录）。
    for (final name in oldDiary.videoName) {
      if (newDiary.videoName.contains(name)) continue;
      final thumb = videoThumbnailName(name);
      if (thumb != null) await delete('video', thumb);
    }
  }
}
