import 'dart:io';
import 'dart:typed_data';

import 'package:fast_zip/fast_zip.dart' as archive;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_sync/src/data/archive_apply.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/incremental_engine.dart';
import 'package:moodiary_sync/src/data/media_refs.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_stores.dart';
import 'package:path/path.dart' as p;

class LocalArchive {
  LocalArchive._();

  static Future<String> export() {
    return IncrementalSyncEngine.runExclusive(() async {
      final diaries = await RepoSyncDiaryStore().getAllDiaries();
      final categories = await RepoSyncCategoryStore()
          .getAllCategoriesForSync();
      final places = await RepoSyncPlaceStore().getAllPlacesForSync();
      final mediaInfos = await RepoSyncMediaInfoStore()
          .getAllMediaInfosForSync();
      final tombstones = await RepoSyncTombstoneStore().getAll();
      final zipPath = p.join(
        PlatformService.get().applicationCachePath,
        _fileName(.now()),
      );
      await archive.FastZip.ensureInitialized();
      final zip = await archive.Zip.newInstance(filePath: zipPath);
      try {
        await writeArchive(
          sink: _RustZipSink(zip),
          diaries: diaries,
          categories: categories,
          places: places,
          mediaInfos: mediaInfos,
          tombstones: tombstones,
          mediaBaseDir: PlatformService.get().applicationSupportPath,
        );
      } catch (_) {
        zip.dispose();
        try {
          await File(zipPath).delete();
        } catch (_) {}
        rethrow;
      }
      zip.dispose();
      return zipPath;
    });
  }

  static String _fileName(DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'moodiary-backup-${now.year}${two(now.month)}${two(now.day)}'
        '-${two(now.hour)}${two(now.minute)}${two(now.second)}.zip';
  }

  static Future<(String, int)> exportDelta({
    required SyncManifest remote,
    required String zipPassword,
  }) {
    return IncrementalSyncEngine.runExclusive(() async {
      final diaries = await RepoSyncDiaryStore().getAllDiaries();
      final categories = await RepoSyncCategoryStore()
          .getAllCategoriesForSync();
      final places = await RepoSyncPlaceStore().getAllPlacesForSync();
      final mediaInfos = await RepoSyncMediaInfoStore()
          .getAllMediaInfosForSync();
      final tombstones = await RepoSyncTombstoneStore().getAll();
      final zipPath = p.join(
        PlatformService.get().applicationCachePath,
        _fileName(.now()),
      );
      await archive.FastZip.ensureInitialized();
      final zip = await archive.Zip.newInstance(filePath: zipPath);
      final int count;
      try {
        count = await writeArchive(
          sink: _RustZipSink(zip, zipPassword),
          diaries: diaries,
          categories: categories,
          places: places,
          mediaInfos: mediaInfos,
          tombstones: tombstones,
          mediaBaseDir: PlatformService.get().applicationSupportPath,
          remote: remote,
        );
      } catch (_) {
        zip.dispose();
        try {
          await File(zipPath).delete();
        } catch (_) {}
        rethrow;
      }
      zip.dispose();
      return (zipPath, count);
    });
  }

  static Future<SyncManifest> buildLocalManifest() async => buildManifest(
    diaries: await RepoSyncDiaryStore().getAllDiaries(),
    categories: await RepoSyncCategoryStore().getAllCategoriesForSync(),
    places: await RepoSyncPlaceStore().getAllPlacesForSync(),
    mediaInfos: await RepoSyncMediaInfoStore().getAllMediaInfosForSync(),
    tombstones: await RepoSyncTombstoneStore().getAll(),
    mediaBaseDir: PlatformService.get().applicationSupportPath,
  );

  static Future<SyncManifest> buildManifest({
    required List<Diary> diaries,
    required List<Category> categories,
    List<Place> places = const [],
    List<MediaInfo> mediaInfos = const [],
    required List<SyncTombstone> tombstones,
    required String mediaBaseDir,
  }) async {
    final entries = <String, ManifestEntry>{};
    for (final tombstone in tombstones) {
      entries[tombstone.key] = ManifestEntry(
        timeMs: tombstone.timeMs,
        deleted: true,
      );
    }
    for (final diary in diaries) {
      final refs = <String>[];
      for (final (type, filename) in collectDiaryMediaEntries(diary)) {
        if (await File(p.join(mediaBaseDir, type, filename)).exists()) {
          refs.add(SyncKeys.mediaRef(type, filename));
        }
      }
      entries[SyncKeys.diary(diary.id)] = ManifestEntry(
        timeMs: diary.lastModified.millisecondsSinceEpoch,
        media: refs,
      );
    }
    for (final category in categories) {
      entries[SyncKeys.category(category.id)] = ManifestEntry(
        timeMs: category.lastModified.millisecondsSinceEpoch,
      );
    }
    for (final place in places) {
      entries[SyncKeys.place(place.id)] = ManifestEntry(
        timeMs: place.lastModified.millisecondsSinceEpoch,
      );
    }
    for (final mediaInfo in mediaInfos) {
      entries[SyncKeys.mediaInfo(mediaInfo.fileName)] = ManifestEntry(
        timeMs: mediaInfo.lastModified.millisecondsSinceEpoch,
      );
    }
    return SyncManifest(
      version: SyncManifest.currentVersion,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      entries: entries,
    );
  }

  @visibleForTesting
  static Future<int> writeArchive({
    required ArchiveSink sink,
    required List<Diary> diaries,
    required List<Category> categories,
    List<Place> places = const [],
    List<MediaInfo> mediaInfos = const [],
    required List<SyncTombstone> tombstones,
    required String mediaBaseDir,
    SyncManifest? remote,
  }) async {
    const cipher = SyncCipher.plaintext;
    final manifest = await buildManifest(
      diaries: diaries,
      categories: categories,
      places: places,
      mediaInfos: mediaInfos,
      tombstones: tombstones,
      mediaBaseDir: mediaBaseDir,
    );

    bool include(String key, ManifestEntry entry) {
      if (remote == null) return true;
      final remoteEntry = remote.entries[key];
      if (remoteEntry == null) return !entry.deleted;
      if (entry.timeMs > remoteEntry.timeMs) return true;
      if (entry.deleted || remoteEntry.deleted) return false;
      final remoteRefs = remoteEntry.media.toSet();
      return entry.media.any((ref) => !remoteRefs.contains(ref));
    }

    final included = <String, ManifestEntry>{
      for (final e in manifest.entries.entries)
        if (include(e.key, e.value)) e.key: e.value,
    };

    final diaryById = {for (final d in diaries) d.id: d};
    final categoryById = {for (final c in categories) c.id: c};
    final placeById = {for (final p in places) p.id: p};
    final mediaInfoByName = {for (final m in mediaInfos) m.fileName: m};
    final remoteMedia = remote?.referencedMedia() ?? const <String>{};
    final addedMedia = <String>{};

    for (final entry in included.entries) {
      if (entry.value.deleted) continue;
      if (entry.key.startsWith(SyncKeys.diaryPrefix)) {
        final id = entry.key.substring(SyncKeys.diaryPrefix.length);
        for (final ref in entry.value.media) {
          if (remoteMedia.contains(ref) || !addedMedia.add(ref)) continue;
          final parts = ref.split('/');
          await sink.addLocalFile(
            SyncKeys.mediaObjectPathFromRef(ref),
            p.join(mediaBaseDir, parts[0], parts[1]),
          );
        }
        await sink.addBytes(
          SyncKeys.diaryObjectPath(id),
          await cipher.encode(diaryById[id]!.toJson()),
        );
      } else if (entry.key.startsWith(SyncKeys.categoryPrefix)) {
        final id = entry.key.substring(SyncKeys.categoryPrefix.length);
        await sink.addBytes(
          SyncKeys.categoryObjectPath(id),
          await cipher.encode(categoryById[id]!.toJson()),
        );
      } else if (entry.key.startsWith(SyncKeys.placePrefix)) {
        final id = entry.key.substring(SyncKeys.placePrefix.length);
        await sink.addBytes(
          SyncKeys.placeObjectPath(id),
          await cipher.encode(placeById[id]!.toJson()),
        );
      } else if (entry.key.startsWith(SyncKeys.mediaInfoPrefix)) {
        final id = entry.key.substring(SyncKeys.mediaInfoPrefix.length);
        await sink.addBytes(
          SyncKeys.mediaInfoObjectPath(id),
          await cipher.encode(mediaInfoByName[id]!.toJson()),
        );
      }
    }

    await sink.addBytes(
      SyncKeys.manifestPath,
      await cipher.encode(
        SyncManifest(
          version: SyncManifest.currentVersion,
          updatedAtMs: manifest.updatedAtMs,
          entries: included,
        ).toJson(),
      ),
    );
    await sink.finish();
    return included.length;
  }

  static Future<SyncReport> import(
    String zipPath, {
    String? password,
    archive.CancelToken? cancel,
    ArchiveApplyPolicy policy = const SyncPullPolicy(),
  }) async {
    final extractDir = await Directory(
      PlatformService.get().applicationCachePath,
    ).createTemp('backup-import-');
    try {
      await archive.FastZip.ensureInitialized();
      await archive.Zip.extract(
        zipPath: zipPath,
        destDir: extractDir.path,
        password: password,
        cancel: cancel ?? archive.CancelToken(),
      );
      return await importDirectory(extractDir.path, policy: policy);
    } finally {
      try {
        await extractDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  static Future<bool> _looksLikeLegacyBackup(String dir) async {
    if (await File(p.join(dir, 'database', 'default.isar')).exists()) {
      return true;
    }
    final root = Directory(dir);
    if (!await root.exists()) return false;
    await for (final entry in root.list(followLinks: false)) {
      if (entry is File && p.extension(entry.path) == '.isar') return true;
    }
    return false;
  }

  @visibleForTesting
  static Future<SyncReport> importDirectory(
    String dir, {
    SyncDiaryStore? diaryStore,
    SyncCategoryStore? categoryStore,
    SyncPlaceStore? placeStore,
    SyncMediaInfoStore? mediaInfoStore,
    SyncTombstoneStore? tombstoneStore,
    SyncMediaFiles? mediaFiles,
    Future<SyncCipher> Function()? cipherProvider,
    int? concurrency,
    ArchiveApplyPolicy policy = const SyncPullPolicy(),
  }) async {
    if (!await File(p.join(dir, SyncKeys.manifestPath)).exists()) {
      if (await _looksLikeLegacyBackup(dir)) {
        throw SyncException(l10n.sync.errLegacyBackup);
      }
      throw SyncException(l10n.sync.errNotBackup);
    }
    final backend = LocalArchiveBackend(dir);
    final cipher = cipherProvider ?? SyncCipher.current;
    final bytes = await backend.readObject(SyncKeys.manifestPath);
    if (bytes == null) throw SyncException(l10n.sync.errNotBackup);
    final decoded = await (await cipher()).decode(bytes);
    if (decoded is! Map<String, dynamic>) {
      throw SyncException(l10n.sync.errManifestCorrupt);
    }
    return runSyncExclusive(
      () => ArchiveApplier(
        backend,
        policy: policy,
        diaryStore: diaryStore,
        categoryStore: categoryStore,
        placeStore: placeStore,
        mediaInfoStore: mediaInfoStore,
        tombstoneStore: tombstoneStore,
        mediaFiles: mediaFiles,
        cipherProvider: cipher,
        concurrency: concurrency ?? 4,
      ).apply(SyncManifest.fromJson(decoded)),
    );
  }
}

abstract interface class ArchiveSink {
  Future<void> addBytes(String zipPath, Uint8List data);
  Future<void> addLocalFile(String zipPath, String filePath);
  Future<void> finish();
}

class _RustZipSink implements ArchiveSink {
  final archive.Zip _zip;
  final String? _password;

  _RustZipSink(this._zip, [this._password]);

  @override
  Future<void> addBytes(String zipPath, Uint8List data) =>
      _zip.addBytes(zipPath: zipPath, data: data, password: _password);

  @override
  Future<void> addLocalFile(String zipPath, String filePath) => _zip.addFile(
    filePath: filePath,
    zipPath: zipPath,
    password: _password,
    stored: true,
  );

  @override
  Future<void> finish() => _zip.finish();
}

class LocalArchiveBackend implements RemoteObjectStore {
  final String root;

  LocalArchiveBackend(this.root);

  File _file(String key) => File(p.join(root, key));

  @override
  String get displayName => '本地备份';

  @override
  String? get persistentBackendId => null;

  @override
  Future<Uint8List?> readObject(String key) async {
    final file = _file(key);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  bool get supportsFileObjects => true;

  @override
  Future<bool> readObjectToFile(String key, String filePath) async {
    final file = _file(key);
    if (!await file.exists()) return false;
    await File(filePath).parent.create(recursive: true);
    await file.copy(filePath);
    return true;
  }

  @override
  Future<void> writeObjectFile(String key, String filePath) async {
    final file = _file(key);
    await file.parent.create(recursive: true);
    await File(filePath).copy(file.path);
  }

  @override
  Future<void> writeObject(String key, Uint8List bytes) async {
    final file = _file(key);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  }

  @override
  Future<bool> tryCreateExclusive(String key, Uint8List bytes) async {
    final file = _file(key);
    await file.parent.create(recursive: true);
    try {
      await file.create(exclusive: true);
    } on PathExistsException {
      return false;
    }
    await file.writeAsBytes(bytes);
    return true;
  }

  @override
  Future<void> deleteObject(String key) async {
    final file = _file(key);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<String?> statObject(String key) async {
    final file = _file(key);
    if (!await file.exists()) return null;
    return (await file.lastModified()).toUtc().toIso8601String();
  }
}
