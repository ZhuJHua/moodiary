import 'dart:io';

import 'package:fast_image/fast_image.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
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
      createDir(imageThumbDir),
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

  static String get imageDir => join(_filePath, 'image');

  static String get imageThumbDir => join(_filePath, 'image', 'thumb');

  static Future<void> deleteImage(String name) async {
    await deleteFile(getRealPath('image', name));
    await FastImageDerivatives.deleteFor(name);
  }

  static Future<void> resetUserMediaDirs() async {
    await Future.wait([
      deleteDir(join(_filePath, 'image')),
      deleteDir(join(_filePath, 'audio')),
      deleteDir(join(_filePath, 'video')),
      deleteDir(join(_filePath, 'font')),
    ]);
    await initCreateDir();
  }

  static String? thumbnailNameOf(String videoName) {
    if (!videoName.startsWith('video-')) return null;
    final dotIdx = videoName.lastIndexOf('.');
    if (dotIdx <= 6) return null;
    return 'thumbnail-${videoName.substring(6, dotIdx)}.jpeg';
  }

  static String getRealPath(String fileType, String fileName) {
    if (fileType == 'thumbnail') {
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
      if (mediaType == MediaType.image.value) {
        await deleteImage(name);
        continue;
      }
      final filePath = getRealPath(mediaType, name);
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  static Future<MediaCleanupReport> scanOrphanMedia({
    required Set<String> usedImages,
    required Set<String> usedAudios,
    required Set<String> usedVideos,
  }) async {
    final orphans = <(String type, Set<String> names)>[
      (
        MediaType.image.value,
        (await getDirFileName(MediaType.image.value))
            .toSet()
            .difference(usedImages),
      ),
      (
        MediaType.audio.value,
        (await getDirFileName(MediaType.audio.value))
            .toSet()
            .difference(usedAudios),
      ),
      (
        MediaType.video.value,
        (await getDirFileName(MediaType.video.value))
            .toSet()
            .difference(usedVideos),
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
    for (final path in await FastImageDerivatives.stale(
      await getDirFileName(MediaType.image.value),
    )) {
      bytes += await File(path).length();
      paths.add(path);
    }
    return MediaCleanupReport(paths: paths, bytes: bytes);
  }

  static Future<void> deleteOrphanMedia(MediaCleanupReport report) async {
    final imageDir = join(_filePath, 'image');
    await Future.wait(
      report.paths.map((path) async {
        await deleteFile(path);
        if (dirname(path) == imageDir) {
          await FastImageDerivatives.deleteFor(basename(path));
        }
      }),
    );
  }

  static String getCachePath(String fileName) {
    return join(_cachePath, fileName);
  }

  static String getErrorLogPath() {
    return join(_filePath, 'error.log');
  }
}

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
