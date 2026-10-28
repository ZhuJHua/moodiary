import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import 'app_files.dart';

/// Physical areas, independent of diary/domain models.
enum StorageArea {
  model,
  database,
  font,
  image,
  audio,
  video,
  file,
  cache,
  logs,
  legacyBackups,
  other,
}

class StorageScanProgress {
  final Map<StorageArea, int> bytes;
  final Set<StorageArea> done;
  final StorageArea area;
  final int files;
  final int reclaimableCacheBytes;

  const StorageScanProgress({
    required this.bytes,
    required this.done,
    required this.area,
    required this.files,
    required this.reclaimableCacheBytes,
  });

  int get total => bytes.values.fold(0, (a, b) => a + b);
  bool get complete => done.length == StorageArea.values.length;
}

class StorageScanner {
  final String supportPath;
  final String cachePath;

  StorageScanner({String? supportPath, String? cachePath})
    : supportPath = supportPath ?? AppFiles.getRealPath('', ''),
      cachePath = cachePath ?? AppFiles.getCachePath('');

  /// All filesystem traversal and stat calls run in a cancellable worker.
  Stream<StorageScanProgress> scan() async* {
    final port = ReceivePort();
    Isolate? worker;
    try {
      worker = await Isolate.spawn(_scan, (
        port.sendPort,
        supportPath,
        cachePath,
      ));
      await for (final event in port) {
        if (event == null) break;
        if (event is StorageScanProgress) {
          yield event;
        } else if (event is List<String>) {
          Error.throwWithStackTrace(
            FileSystemException(event[0]),
            StackTrace.fromString(event[1]),
          );
        }
      }
    } finally {
      port.close();
      worker?.kill(priority: Isolate.immediate);
    }
  }
}

const legacyDatabaseBackupNames = {
  'default.isar.pre-sqlite.bak',
  'default.isar.v273bak',
};

void _scan((SendPort, String, String) args) {
  final (port, support, cache) = args;
  final bytes = {for (final area in StorageArea.values) area: 0};
  final done = <StorageArea>{};
  var files = 0;
  var cacheBytes = 0;
  var sinceEmit = 0;
  final watch = Stopwatch()..start();
  var current = StorageArea.model;
  void emit() {
    port.send(
      StorageScanProgress(
        bytes: Map.of(bytes),
        done: Set.of(done),
        area: current,
        files: files,
        reclaimableCacheBytes: cacheBytes,
      ),
    );
    watch.reset();
    sinceEmit = 0;
  }

  void walk(
    FileSystemEntity entity,
    StorageArea area, {
    bool reclaimable = false,
  }) {
    try {
      final type = FileSystemEntity.typeSync(entity.path, followLinks: false);
      if (type == FileSystemEntityType.file) {
        final size = File(entity.path).lengthSync();
        bytes[area] = bytes[area]! + size;
        if (reclaimable) cacheBytes += size;
        files++;
        sinceEmit++;
        if (sinceEmit >= 200 || watch.elapsedMilliseconds >= 120) emit();
      } else if (type == FileSystemEntityType.directory) {
        for (final child in Directory(
          entity.path,
        ).listSync(followLinks: false)) {
          walk(child, area, reclaimable: reclaimable);
        }
      }
      // Symlinks are neither followed nor counted; cleanup never follows them.
    } on PathNotFoundException {
      // Files may disappear during downloads, sync, or log rotation.
    }
  }

  try {
    emit();
    // Cheap stat-only areas first, then the potentially large directory walks.
    for (final area in StorageArea.values) {
      current = area;
      if (area == StorageArea.cache) {
        final directory = Directory(cache);
        if (directory.existsSync()) {
          for (final child in directory.listSync(followLinks: false)) {
            walk(
              child,
              area,
              reclaimable: !AppFiles.protectedCacheDirectories.contains(
                p.basename(child.path),
              ),
            );
          }
        }
      } else if (area == StorageArea.database) {
        final directory = Directory(p.join(support, 'database'));
        if (directory.existsSync()) {
          for (final child in directory.listSync(followLinks: false)) {
            if (!legacyDatabaseBackupNames.contains(p.basename(child.path))) {
              walk(child, area);
            }
          }
        }
      } else if (area == StorageArea.legacyBackups) {
        for (final name in legacyDatabaseBackupNames) {
          walk(File(p.join(support, 'database', name)), area);
        }
        walk(Directory(p.join(support, 'migration_backup')), area);
      } else if (area == StorageArea.logs || area == StorageArea.other) {
        final directory = Directory(support);
        if (directory.existsSync()) {
          const known = {
            'model',
            'database',
            'font',
            'image',
            'audio',
            'video',
            'file',
            'migration_backup',
          };
          for (final child in directory.listSync(followLinks: false)) {
            final name = p.basename(child.path);
            final log = name.startsWith('error.log') || name == 'sync_logs';
            if (area == StorageArea.logs
                ? log
                : !log &&
                      !known.contains(name) &&
                      p.normalize(child.path) != p.normalize(cache)) {
              walk(child, area);
            }
          }
        }
      } else {
        walk(Directory(p.join(support, area.name)), area);
      }
      done.add(area);
      emit();
    }
  } catch (error, stack) {
    port.send([error.toString(), stack.toString()]);
  } finally {
    port.send(null);
  }
}
