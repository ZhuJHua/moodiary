import 'dart:io';

import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_core/src/values/media_type.dart';
import 'package:moodiary_core/src/platform_service.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class AppFiles {
  static final String _filePath = PlatformService.get().applicationSupportPath;

  static final String _cachePath = PlatformService.get().applicationCachePath;

  static Future<bool> deleteFile(String path) async {
    final File file = File(path);
    if (await file.exists()) {
      await file.delete();
      return true;
    } else {
      return false;
    }
  }

  static String getErrorLogFilePath() {
    return join(_filePath, 'error.log');
  }

  static Future<void> deleteDir(String path) async {
    final Directory directory = Directory(path);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  static Future<void> initCreateDir() async {
    await Future.wait([
      createDir(join(_filePath, 'database')),
      createDir(join(_filePath, 'image')),
      createDir(join(_filePath, 'audio')),
      createDir(join(_filePath, 'video')),
      createDir(join(_filePath, 'font')),
    ]);
  }

  static Future<void> createDir(String path) async {
    final Directory directory = Directory(path);
    await directory.create(recursive: true);
  }

  static Future<Map<String, dynamic>> countSize() async {
    final cacheDir = await getApplicationCacheDirectory();
    var bytes = 0;
    final fileList = cacheDir.listSync(recursive: true);
    for (final file in fileList) {
      if (file is File) {
        bytes += file.lengthSync();
      }
    }
    return bytesToUnits(bytes);
  }

  static Map<String, dynamic> bytesToUnits(int bytes) {
    if (bytes < 1024) {
      return {'size': bytes.toString(), 'unit': 'B', 'bytes': bytes};
    } else if (bytes < 1024 * 1024) {
      return {
        'size': (bytes / 1024).toStringAsFixed(2),
        'unit': 'KB',
        'bytes': bytes,
      };
    } else if (bytes < 1024 * 1024 * 1024) {
      return {
        'size': (bytes / (1024 * 1024)).toStringAsFixed(2),
        'unit': 'MB',
        'bytes': bytes,
      };
    } else {
      return {
        'size': (bytes / (1024 * 1024 * 1024)).toStringAsFixed(2),
        'unit': 'GB',
        'bytes': bytes,
      };
    }
  }

  static Future<void> clearCache() async {
    final cacheDir = await getApplicationCacheDirectory();
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
  }

  /// 删除用户媒体目录后重建为空。不动 `database` 目录——它由打开中的 Isar 句柄
  /// 管理，须改用 [IsarDatabase.clear]，直接删目录会损坏句柄。
  static Future<void> resetUserMediaDirs() async {
    await Future.wait([
      deleteDir(join(_filePath, 'image')),
      deleteDir(join(_filePath, 'audio')),
      deleteDir(join(_filePath, 'video')),
      deleteDir(join(_filePath, 'font')),
    ]);
    await initCreateDir();
  }

  /// 视频文件名 `video-<uuid>.<ext>` → 缩略图名 `thumbnail-<uuid>.jpeg`（同在 video/ 目录）。
  /// 这是**全仓唯一**的派生实现 —— 之前散着六份、还分两套公式（定长 substring(6,42) 与按点号
  /// 定位），标准名下一致、非标准名下会算出不同的名字，core 与 sync 因此可能各认一个缩略图。
  ///
  /// 名字不合约定时返回 null。裸 substring 会**同步抛 RangeError**：那是在 build 方法里红屏，
  /// 不是「没有封面」这种可降级的情况。
  static String? thumbnailNameOf(String videoName) {
    if (!videoName.startsWith('video-')) return null;
    final dotIdx = videoName.lastIndexOf('.');
    if (dotIdx <= 6) return null;
    return 'thumbnail-${videoName.substring(6, dotIdx)}.jpeg';
  }

  static String getRealPath(String fileType, String fileName) {
    if (fileType == 'thumbnail') {
      // 派生不出规范名就退回一个必然不存在的路径：调用方本来就在判存在性 / 用 errorBuilder，
      // 抛异常会把「没有封面」升级成崩溃。
      final name = thumbnailNameOf(fileName) ?? 'thumbnail-$fileName.jpeg';
      return join(_filePath, 'video', name);
    }
    return join(_filePath, fileType, fileName);
  }

  static Future<List<String>> getDirFilePath(String fileType) async {
    final path = join(_filePath, fileType);
    final List<String> filePaths = [];
    final Directory directory = Directory(path);
    if (await directory.exists()) {
      await for (final entity in directory.list()) {
        if (entity is File) {
          filePaths.add(entity.path);
        }
      }
    }
    return filePaths;
  }

  static Future<List<String>> getDirFileName(String fileType) async {
    final path = join(_filePath, fileType);
    final List<String> fileNames = [];
    final Directory directory = Directory(path);
    if (await directory.exists()) {
      await for (final entity in directory.list()) {
        if (entity is File) {
          fileNames.add(basename(entity.path));
        }
      }
    }
    return fileNames;
  }

  static Future<void> deleteMediaFiles(
    Set<String> files,
    String mediaType,
  ) async {
    for (final name in files) {
      final filePath = getRealPath(mediaType, name);
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  /// 扫描未被任何日记引用的「孤儿」媒体文件（不删除）。调用方须传入全量引用集
  /// （含回收站/草稿）；[usedVideos] 须含 thumbnail 名（缩略图与视频同存 `video`）。
  static Future<MediaCleanupReport> scanOrphanMedia({
    required Set<String> usedImages,
    required Set<String> usedAudios,
    required Set<String> usedVideos,
  }) async {
    final orphans = <(String type, Set<String> names)>[
      (
        MediaType.image.value,
        (await getDirFileName(
          MediaType.image.value,
        )).toSet().difference(usedImages),
      ),
      (
        MediaType.audio.value,
        (await getDirFileName(
          MediaType.audio.value,
        )).toSet().difference(usedAudios),
      ),
      (
        MediaType.video.value,
        (await getDirFileName(
          MediaType.video.value,
        )).toSet().difference(usedVideos),
      ),
    ];

    final paths = <String>[];
    var bytes = 0;
    for (final (type, names) in orphans) {
      for (final name in names) {
        final file = File(getRealPath(type, name));
        if (await file.exists()) {
          bytes += await file.length();
          paths.add(file.path);
        }
      }
    }
    return MediaCleanupReport(paths: paths, bytes: bytes);
  }

  static Future<void> deleteOrphanMedia(MediaCleanupReport report) async {
    await Future.wait(report.paths.map(deleteFile));
  }

  static String getCachePath(String fileName) {
    return join(_cachePath, fileName);
  }

  static String getErrorLogPath() {
    return join(_filePath, 'error.log');
  }

  static Future<void> cleanFile(String dir) async {
    final isar = Isar.open(
      schemas: [DiarySchema, CategorySchema],
      directory: dir,
    );
    final imageFiles = (await AppFiles.getDirFileName(
      MediaType.image.value,
    )).toSet();
    final audioFiles = (await AppFiles.getDirFileName(
      MediaType.audio.value,
    )).toSet();
    final videoFiles = (await AppFiles.getDirFileName(
      MediaType.video.value,
    )).toSet();

    final usedImages = <String>{};
    final usedAudios = <String>{};
    final usedVideos = <String>{};

    final count = isar.diarys.count();

    const batchSize = 50;
    for (int i = 0; i < count; i += batchSize) {
      final diaryList = await isar.diarys.where().findAllAsync(
        offset: i,
        limit: batchSize,
      );
      for (final diary in diaryList) {
        usedImages.addAll(diary.imageName);
        usedAudios.addAll(diary.audioName);
        usedVideos.addAll(diary.videoName);
        for (final name in diary.videoName) {
          // 派生不出名字说明当初也生成不出缩略图，没有对应文件要保留。
          final thumbnailName = thumbnailNameOf(name);
          if (thumbnailName != null) usedVideos.add(thumbnailName);
        }
      }
    }

    final imagesToDelete = imageFiles.difference(usedImages);
    final audiosToDelete = audioFiles.difference(usedAudios);
    final videosToDelete = videoFiles.difference(usedVideos);

    await Future.wait([
      AppFiles.deleteMediaFiles(imagesToDelete, MediaType.image.value),
      AppFiles.deleteMediaFiles(audiosToDelete, MediaType.audio.value),
      AppFiles.deleteMediaFiles(videosToDelete, MediaType.video.value),
    ]);
  }
}

/// [AppFiles.scanOrphanMedia] 的结果：待清理的孤儿媒体文件绝对路径及其总字节数。
class MediaCleanupReport {
  final List<String> paths;

  final int bytes;

  const MediaCleanupReport({required this.paths, required this.bytes});

  int get count => paths.length;

  bool get isEmpty => paths.isEmpty;

  String get readableSize {
    final unit = AppFiles.bytesToUnits(bytes);
    return '${unit['size']} ${unit['unit']}';
  }
}
