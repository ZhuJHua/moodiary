import 'dart:io';
import 'dart:isolate';

import 'package:fast_image/fast_image.dart';
import 'package:path/path.dart' as p;

import 'app_files.dart';
import 'media_type.dart';

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
  other;

  MediaType? get mediaType => switch (this) {
    .image => .image,
    .audio => .audio,
    .video => .video,
    .file => .file,
    _ => null,
  };
}

enum StorageCleanupKind {
  retiredModel,
  unusedModel,
  partialDownload,
  cache,
  unusedMedia,
  legacyBackup;

  Set<StorageArea> get areas => switch (this) {
    .retiredModel || .unusedModel || .partialDownload => const {.model},
    .cache => const {.cache},
    .unusedMedia => const {.image, .audio, .video, .file},
    .legacyBackup => const {.legacyBackups},
  };
}

typedef ReferencedMedia = ({
  Set<String> images,
  Set<String> audios,
  Set<String> videos,
  Set<String> files,
});

/// Only filenames and flags cross into the scanner isolate.
class StorageScanInput {
  final ReferencedMedia referencedMedia;
  final Set<String> liveModelFiles;
  final Set<String> retiredModelStems;
  final bool includeLegacyBackups;
  final Set<String> _imageStems;
  final Set<String> _videos;

  StorageScanInput({
    ReferencedMedia referencedMedia = (
      images: const {},
      audios: const {},
      videos: const {},
      files: const {},
    ),
    Set<String> liveModelFiles = const {},
    Set<String> retiredModelStems = const {},
    this.includeLegacyBackups = false,
  }) : referencedMedia = (
         images: Set.unmodifiable(referencedMedia.images),
         audios: Set.unmodifiable(referencedMedia.audios),
         videos: Set.unmodifiable(referencedMedia.videos),
         files: Set.unmodifiable(referencedMedia.files),
       ),
       liveModelFiles = Set.unmodifiable(liveModelFiles),
       retiredModelStems = Set.unmodifiable(retiredModelStems),
       _imageStems = {
         for (final name in referencedMedia.images)
           p.basenameWithoutExtension(name),
       },
       _videos = {
         ...referencedMedia.videos,
         for (final name in referencedMedia.videos)
           if (AppFiles.thumbnailNameOf(name) case final String thumb) thumb,
       };

  /// Recheck a snapshot against fresh references without walking media again.
  bool references(StorageCandidate file) {
    if (file.imageStem case final String stem) {
      return _imageStems.contains(stem);
    }
    final names = switch (file.area) {
      .image => referencedMedia.images,
      .audio => referencedMedia.audios,
      .video => _videos,
      .file => referencedMedia.files,
      _ => const <String>{},
    };
    return names.contains(file.mediaName);
  }
}

class StorageCandidate {
  final String path;
  final int bytes;
  final StorageArea area;

  /// Present for originals and video thumbnails, absent for image derivatives.
  final String? mediaName;
  final String? imageStem;

  const StorageCandidate({
    required this.path,
    required this.bytes,
    required this.area,
    this.mediaName,
    this.imageStem,
  });
}

class StorageCandidates {
  final List<StorageCandidate> files;
  final int bytes;
  final Map<MediaType, int> counts;
  final Map<StorageArea, int> areaBytes;

  StorageCandidates(Iterable<StorageCandidate> files)
    : files = List.unmodifiable(files),
      bytes = files.fold(0, (sum, file) => sum + file.bytes),
      counts = Map.unmodifiable({
        for (final type in MediaType.values)
          if (files.any((f) => _counted(f, type)))
            type: files.where((f) => _counted(f, type)).length,
      }),
      areaBytes = Map.unmodifiable({
        for (final area in files.map((f) => f.area).toSet())
          area: files
              .where((f) => f.area == area)
              .fold(0, (sum, f) => sum + f.bytes),
      });

  static bool _counted(StorageCandidate file, MediaType type) =>
      file.area.mediaType == type &&
      file.mediaName != null &&
      !file.mediaName!.startsWith('thumbnail-');
}

class StorageReport {
  final Map<StorageArea, int> bytes;
  final Set<StorageArea> done;
  final StorageArea area;
  final int files;

  /// A kind is published only once all its areas are done.
  final Map<StorageCleanupKind, StorageCandidates> candidates;

  StorageReport({
    required Map<StorageArea, int> bytes,
    required Set<StorageArea> done,
    required this.area,
    required this.files,
    Map<StorageCleanupKind, StorageCandidates> candidates = const {},
  }) : bytes = Map.unmodifiable(bytes),
       done = Set.unmodifiable(done),
       candidates = Map.unmodifiable(candidates);

  int get total => bytes.values.fold(0, (a, b) => a + b);
  bool get complete => done.length == StorageArea.values.length;
  bool finished(StorageCleanupKind kind) => done.containsAll(kind.areas);

  /// This report as it will look once [kinds] are deleted: their candidates
  /// are dropped and their bytes taken out of the areas they lived in.
  StorageReport without(Set<StorageCleanupKind> kinds) {
    final remaining = {...bytes};
    for (final kind in kinds) {
      for (final MapEntry(key: area, value: freed)
          in candidates[kind]?.areaBytes.entries ??
              const <MapEntry<StorageArea, int>>[]) {
        remaining[area] = ((remaining[area] ?? 0) - freed).clamp(0, 1 << 62);
      }
    }
    return StorageReport(
      bytes: remaining,
      done: done,
      area: area,
      files: files,
      candidates: {
        for (final MapEntry(:key, :value) in candidates.entries)
          if (!kinds.contains(key)) key: value,
      },
    );
  }
}

class StorageScanner {
  final String supportPath;
  final String cachePath;

  StorageScanner({String? supportPath, String? cachePath})
    : supportPath = supportPath ?? AppFiles.getRealPath('', ''),
      cachePath = cachePath ?? AppFiles.getCachePath('');

  /// All filesystem traversal and stat calls run in a cancellable worker.
  Stream<StorageReport> scan(StorageScanInput input) async* {
    final port = ReceivePort();
    Isolate? worker;
    try {
      worker = await Isolate.spawn(_scan, (
        port.sendPort,
        supportPath,
        cachePath,
        input,
      ));
      await for (final event in port) {
        if (event == null) break;
        if (event is StorageReport) {
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

void _scan((SendPort, String, String, StorageScanInput) args) {
  final (port, support, cache, input) = args;
  final bytes = {for (final area in StorageArea.values) area: 0};
  final done = <StorageArea>{};
  final pending = {
    for (final kind in StorageCleanupKind.values) kind: <StorageCandidate>[],
  };
  final candidates = <StorageCleanupKind, StorageCandidates>{};
  var files = 0;
  var sinceEmit = 0;
  final watch = Stopwatch()..start();
  final now = DateTime.now();
  var current = StorageArea.model;
  void emit() {
    port.send(
      StorageReport(
        bytes: bytes,
        done: done,
        area: current,
        files: files,
        candidates: candidates,
      ),
    );
    watch.reset();
    sinceEmit = 0;
  }

  void walk(
    FileSystemEntity entity,
    StorageArea area, {
    StorageCleanupKind? kind,
  }) {
    try {
      // Never stat the target of a link or traverse it.
      if (FileSystemEntity.isLinkSync(entity.path)) return;
      final stat = entity.statSync();
      if (stat.type == FileSystemEntityType.file) {
        final size = stat.size;
        bytes[area] = bytes[area]! + size;
        final name = p.basename(entity.path);
        var candidate = StorageCandidate(
          path: entity.path,
          bytes: size,
          area: area,
        );
        if (area == .model) {
          if (name.endsWith('.part')) {
            kind = .partialDownload;
          } else if (input.retiredModelStems.any(
            (stem) => name == stem || name.startsWith('$stem.'),
          )) {
            kind = .retiredModel;
          } else if (!input.liveModelFiles.contains(name)) {
            kind = .unusedModel;
          }
        } else if (area.mediaType != null) {
          final relative = p.relative(
            entity.path,
            from: p.join(support, area.name),
          );
          if (p.dirname(relative) == '.') {
            candidate = StorageCandidate(
              path: entity.path,
              bytes: size,
              area: area,
              mediaName: name,
            );
            if (!input.references(candidate)) kind = .unusedMedia;
          } else if (area == .image &&
              p.dirname(relative) == 'thumb' &&
              FastImageDerivatives.isStale(
                name,
                input._imageStems,
                modified: stat.modified,
                now: now,
              )) {
            candidate = StorageCandidate(
              path: entity.path,
              bytes: size,
              area: area,
              imageStem: FastImageDerivatives.sourceStem(name),
            );
            kind = .unusedMedia;
          }
        }
        if (kind != null) pending[kind]!.add(candidate);
        files++;
        sinceEmit++;
        if (sinceEmit >= 200 || watch.elapsedMilliseconds >= 120) emit();
      } else if (stat.type == FileSystemEntityType.directory) {
        for (final child in Directory(
          entity.path,
        ).listSync(followLinks: false)) {
          walk(child, area, kind: kind);
        }
      }
    } on PathNotFoundException {
      // Files may disappear during downloads, sync, or log rotation.
    }
  }

  try {
    emit();
    // Small areas first, before the potentially large media directory walks.
    for (final area in [
      StorageArea.model,
      StorageArea.database,
      StorageArea.font,
      StorageArea.legacyBackups,
      StorageArea.logs,
      StorageArea.other,
      StorageArea.image,
      StorageArea.audio,
      StorageArea.video,
      StorageArea.file,
      StorageArea.cache,
    ]) {
      current = area;
      if (area == StorageArea.cache) {
        final directory = Directory(cache);
        if (directory.existsSync()) {
          for (final child in directory.listSync(followLinks: false)) {
            walk(
              child,
              area,
              kind:
                  AppFiles.protectedCacheDirectories.contains(
                    p.basename(child.path),
                  )
                  ? null
                  : .cache,
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
          walk(
            File(p.join(support, 'database', name)),
            area,
            kind: input.includeLegacyBackups ? .legacyBackup : null,
          );
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
      for (final kind in StorageCleanupKind.values) {
        if (!candidates.containsKey(kind) && done.containsAll(kind.areas)) {
          candidates[kind] = StorageCandidates(pending[kind]!);
        }
      }
      emit();
    }
  } catch (error, stack) {
    port.send([error.toString(), stack.toString()]);
  } finally {
    port.send(null);
  }
}
