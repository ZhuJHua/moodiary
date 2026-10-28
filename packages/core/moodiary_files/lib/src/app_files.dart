import 'dart:io';
import 'dart:isolate';

import 'package:fast_image/fast_image.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:path/path.dart';

class AppFiles {
  static final String _filePath = PlatformService.get().applicationSupportPath;

  static final String _cachePath = PlatformService.get().applicationCachePath;

  static Future<bool> deleteFile(String path) async {
    final File file = File(path);
    try {
      await file.delete();
      return true;
    } on PathNotFoundException {
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
      createDir(join(_filePath, 'file')),
      createDir(join(_filePath, 'font')),
    ]);
  }

  static Future<void> createDir(String path) async {
    final Directory directory = Directory(path);
    await directory.create(recursive: true);
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

  /// These workspaces can outlive the page that started the job (including
  /// files still owned by the share sheet). Retain them without a job lease.
  static bool isProtectedCacheEntry(String name) =>
      const {'sync-media', 'export', 'import'}.contains(name) ||
      name.startsWith('backup-import-') ||
      (name.startsWith('moodiary-backup-') && name.endsWith('.zip'));

  /// Mirror FastImageDerivatives' grace period for incomplete downloads.
  static const partialDownloadGrace = Duration(hours: 1);

  static Future<int> clearCache({
    String? cachePath,
    bool protectWorkspaces = true,
    Set<String>? filePaths,
  }) {
    final path = cachePath ?? _cachePath;
    return Isolate.run(() {
      var freed = 0;
      void remove(FileSystemEntity entity) {
        try {
          final type = FileSystemEntity.typeSync(
            entity.path,
            followLinks: false,
          );
          if (type == FileSystemEntityType.directory) {
            for (final child in Directory(
              entity.path,
            ).listSync(followLinks: false)) {
              remove(child);
            }
            // Do not recursively delete files another owner created meanwhile.
            Directory(entity.path).deleteSync();
          } else if (type == FileSystemEntityType.file) {
            final file = File(entity.path);
            final bytes = file.lengthSync();
            file.deleteSync();
            freed += bytes;
          } else if (type == FileSystemEntityType.link) {
            Link(entity.path).deleteSync();
          }
        } on PathNotFoundException {
          // Another cache owner already removed it.
        }
      }

      if (filePaths != null) {
        // A report cleanup removes only its snapshot, retaining newly made files.
        for (final filePath in filePaths) {
          if (!isWithin(path, filePath)) continue;
          final top = split(relative(filePath, from: path)).first;
          if (protectWorkspaces && isProtectedCacheEntry(top)) continue;
          if (FileSystemEntity.typeSync(filePath, followLinks: false) ==
              FileSystemEntityType.file) {
            remove(File(filePath));
          }
        }
        return freed;
      }

      final directory = Directory(path);
      if (!directory.existsSync()) return 0;
      for (final child in directory.listSync(followLinks: false)) {
        if (!protectWorkspaces ||
            !isProtectedCacheEntry(basename(child.path))) {
          remove(child);
        }
      }
      return freed;
    });
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
      deleteDir(join(_filePath, 'file')),
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
