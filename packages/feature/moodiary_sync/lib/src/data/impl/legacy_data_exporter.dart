import 'dart:io';

import 'package:fast_zip/fast_zip.dart';
import 'package:injectable/injectable.dart';
import 'package:moodiary_migration/moodiary_migration.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:path/path.dart' as p;

typedef _Entry = ({String path, String name, int size});

@LazySingleton(as: LegacyDataExporter)
class SyncLegacyDataExporter implements LegacyDataExporter {
  SyncLegacyDataExporter()
    : this.withDependencies(
        support: PlatformService.get().applicationSupportDirectory,
        cache: PlatformService.get().applicationCacheDirectory,
        openZip: (path) async {
          await FastZip.ensureInitialized();
          return Zip.newInstance(filePath: path);
        },
      );

  SyncLegacyDataExporter.withDependencies({
    required this._support,
    required this._cache,
    required this._openZip,
  });

  final Directory _support;
  final Directory _cache;
  final Future<Zip> Function(String) _openZip;
  bool _exporting = false;

  Stream<_Entry> _media(Directory directory) async* {
    await for (final child in directory.list(followLinks: false)) {
      final name = p.relative(child.path, from: _support.path);
      if (child is Directory && name != 'image/thumb') {
        yield* _media(child);
      } else if (child is File) {
        yield (path: child.path, name: name, size: await child.length());
      }
    }
  }

  Stream<_Entry> _entries(DateTime date) async* {
    final database = File(p.join(_support.path, 'database', 'default.isar'));
    final stat = await database.stat();
    if (stat.type != FileSystemEntityType.file ||
        stat.size == 0 ||
        await Link(database.path).exists()) {
      throw FileSystemException(
        'Missing or empty legacy database',
        database.path,
      );
    }
    yield (
      path: database.path,
      name: '${date.millisecondsSinceEpoch}.isar',
      size: stat.size,
    );
    for (final name in const ['image', 'audio', 'video', 'font']) {
      final dir = Directory(p.join(_support.path, name));
      if (await FileSystemEntity.type(dir.path, followLinks: false) ==
          FileSystemEntityType.directory) {
        yield* _media(dir);
      }
    }
  }

  @override
  Future<LegacyExportSummary> inspect() async {
    final entries = await _entries(DateTime.now()).toList();
    return (
      databaseBytes: entries.first.size,
      mediaCount: entries.length - 1,
      mediaBytes: entries
          .skip(1)
          .fold<int>(0, (sum, entry) => sum + entry.size),
    );
  }

  @override
  Future<String> export({
    required void Function(int completed, int total) onProgress,
    required bool Function() isCancelled,
  }) async {
    if (_exporting) throw StateError('Legacy export already in progress');
    _exporting = true;
    try {
      await for (final entry in _cache.list(followLinks: false)) {
        if (entry is Directory &&
            p.basename(entry.path).startsWith('legacy-export-')) {
          await entry.delete(recursive: true);
        }
      }
      return await _writeArchive(onProgress, isCancelled);
    } catch (error) {
      if (error is FileSystemException && error.osError?.errorCode == 28 ||
          RegExp(
            r'No space left|os error 28\b',
            caseSensitive: false,
          ).hasMatch(error.toString())) {
        throw const LegacyExportInsufficientSpace();
      }
      rethrow;
    } finally {
      _exporting = false;
    }
  }

  Future<String> _writeArchive(
    void Function(int completed, int total) onProgress,
    bool Function() isCancelled,
  ) async {
    void checkCancellation() {
      if (isCancelled()) throw const LegacyExportCancelled();
    }

    final date = DateTime.now();
    final entries = <_Entry>[];
    await for (final entry in _entries(date)) {
      checkCancellation();
      if (entry.size > 0xffffffff) throw LegacyExportFileTooLarge(entry.name);
      entries.add(entry);
    }
    onProgress(0, entries.length);
    checkCancellation();
    final directory = await _cache.createTemp('legacy-export-');
    final path = p.join(
      directory.path,
      '心绪日记${date.toIso8601String().substring(0, 10)}备份.zip',
    );
    try {
      final zip = await _openZip(path);
      try {
        var completed = 0;
        for (final entry in entries) {
          checkCancellation();
          await zip.addFile(filePath: entry.path, zipPath: entry.name);
          onProgress(++completed, entries.length);
        }
        checkCancellation();
        await zip.finish();
        checkCancellation();
      } finally {
        zip.dispose();
      }
      return path;
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }
}
