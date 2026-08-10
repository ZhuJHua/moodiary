import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_rust/moodiary_rust.dart' as rust;
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/incremental_engine.dart';
import 'package:moodiary_sync/src/data/media_refs.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/model/sync_provider.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_stores.dart';
import 'package:path/path.dart' as p;

/// 本地备份归档 —— 导出/导入 zip，包内布局与远端同步完全一致：
/// `manifest.json` + `diary/<id>.json` + `category/<id>.json` +
/// `media/<type>/<filename>`，一律明文（本地压缩包不加密）。
///
/// - 导出：引擎操作锁内做全量快照（防止媒体被并发同步删除），tombstone 也写进
///   manifest（`d:true`，不带 body），使导入能按 LWW 传播删除；
/// - 导入：解压到缓存目录，用 [LocalArchiveBackend] 直接复用
///   [IncrementalSyncEngine.pull] —— LWW / tombstone / 媒体补拉与云同步一字不差。
///   cipher 走默认 [SyncCipher.current]：明文归档直接通过，用户把远端加密目录
///   打包成 zip 也能凭本地密钥导入。
class LocalArchive {
  LocalArchive._();

  static Future<String> export() {
    return IncrementalSyncEngine.runExclusive(() async {
      final diaries = await RepoSyncDiaryStore().getAllDiaries();
      final categories = await RepoSyncCategoryStore()
          .getAllCategoriesForSync();
      final tombstones = await RepoSyncTombstoneStore().getAll();
      final zipPath = p.join(
        PlatformService.get().applicationCachePath,
        _fileName(.now()),
      );
      // 中途抛错到不了 writeArchive 末尾的 finish()；不 dispose 则 fd 一直攥着，
      // 被删的半成品要等 GC 才真正释放磁盘 —— 而失败原因往往正是磁盘满。
      final zip = await rust.Zip.newInstance(filePath: zipPath);
      try {
        await writeArchive(
          sink: _RustZipSink(zip),
          diaries: diaries,
          categories: categories,
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

  /// 局域网发送：构建针对 [remote] 的增量归档，zip 条目以 [zipPassword] AES-256
  /// 加密。返回 (zip 路径, 条目数)；条目数为 0 表示对方已是最新，调用方直接删掉
  /// 空包即可。
  static Future<(String, int)> exportDelta({
    required SyncManifest remote,
    required String zipPassword,
  }) {
    return IncrementalSyncEngine.runExclusive(() async {
      final diaries = await RepoSyncDiaryStore().getAllDiaries();
      final categories = await RepoSyncCategoryStore()
          .getAllCategoriesForSync();
      final tombstones = await RepoSyncTombstoneStore().getAll();
      final zipPath = p.join(
        PlatformService.get().applicationCachePath,
        _fileName(.now()),
      );
      final zip = await rust.Zip.newInstance(filePath: zipPath);
      final int count;
      try {
        count = await writeArchive(
          sink: _RustZipSink(zip, zipPassword),
          diaries: diaries,
          categories: categories,
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

  /// 局域网接收方：把本机数据投影成 manifest，供发送方算增量。
  static Future<SyncManifest> buildLocalManifest() async => buildManifest(
    diaries: await RepoSyncDiaryStore().getAllDiaries(),
    categories: await RepoSyncCategoryStore().getAllCategoriesForSync(),
    tombstones: await RepoSyncTombstoneStore().getAll(),
    mediaBaseDir: PlatformService.get().applicationSupportPath,
  );

  /// 把本机快照投影成 manifest（entries 含 tombstone；媒体引用只列本地真实存在
  /// 的文件，与 push「不谎报存在」同规则）。导出与局域网接收方共用。
  static Future<SyncManifest> buildManifest({
    required List<Diary> diaries,
    required List<Category> categories,
    required List<SyncTombstone> tombstones,
    required String mediaBaseDir,
  }) async {
    final entries = <String, ManifestEntry>{};
    // 墓碑键（`d:`/`c:` 前缀）与活跃行按不变量互斥，覆盖顺序无关紧要。
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
    return SyncManifest(
      version: SyncManifest.currentVersion,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      entries: entries,
    );
  }

  /// 按远端布局把快照写入 [sink]，返回写入的 manifest 条目数。
  ///
  /// [remote] 非 null 时做增量（局域网发送）：只写比对方新的条目（LWW，含
  /// tombstone；对方从未有过的条目不发 tombstone），对方已有的媒体不进包 ——
  /// 但仍留在条目的 media 列表里（列表描述日记引用了什么，导入端对已存在
  /// 文件本就跳过下载）。过滤只是省带宽：导入端的 engine.pull 才是正确性闸门。
  @visibleForTesting
  static Future<int> writeArchive({
    required ArchiveSink sink,
    required List<Diary> diaries,
    required List<Category> categories,
    required List<SyncTombstone> tombstones,
    required String mediaBaseDir,
    SyncManifest? remote,
  }) async {
    const cipher = SyncCipher.plaintext;
    final manifest = await buildManifest(
      diaries: diaries,
      categories: categories,
      tombstones: tombstones,
      mediaBaseDir: mediaBaseDir,
    );

    bool include(String key, ManifestEntry entry) {
      if (remote == null) return true;
      final remoteEntry = remote.entries[key];
      if (remoteEntry == null) return !entry.deleted;
      return entry.timeMs > remoteEntry.timeMs;
    }

    final included = <String, ManifestEntry>{
      for (final e in manifest.entries.entries)
        if (include(e.key, e.value)) e.key: e.value,
    };

    final diaryById = {for (final d in diaries) d.id: d};
    final categoryById = {for (final c in categories) c.id: c};
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
    rust.CancelToken? cancel,
  }) async {
    final extractDir = await Directory(
      PlatformService.get().applicationCachePath,
    ).createTemp('backup-import-');
    try {
      await rust.Zip.extract(
        zipPath: zipPath,
        destDir: extractDir.path,
        password: password,
        cancel: cancel ?? rust.CancelToken(),
      );
      return await importDirectory(extractDir.path);
    } finally {
      try {
        await extractDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  @visibleForTesting
  static Future<SyncReport> importDirectory(
    String dir, {
    SyncDiaryStore? diaryStore,
    SyncCategoryStore? categoryStore,
    SyncTombstoneStore? tombstoneStore,
    SyncMediaFiles? mediaFiles,
    Future<SyncCipher> Function()? cipherProvider,
    int? concurrency,
  }) async {
    if (!await File(p.join(dir, SyncKeys.manifestPath)).exists()) {
      throw const SyncException('不是有效的 Moodiary 备份文件');
    }
    final engine = IncrementalSyncEngine(
      LocalArchiveBackend(dir),
      diaryStore: diaryStore,
      categoryStore: categoryStore,
      tombstoneStore: tombstoneStore,
      mediaFiles: mediaFiles,
      cipherProvider: cipherProvider,
      concurrency: concurrency,
    );
    return engine.pull(markSynced: false);
  }
}

/// 归档写入端口：生产走 Rust zip（[LocalArchive.export]），测试注入内存实现。
abstract interface class ArchiveSink {
  Future<void> addBytes(String zipPath, Uint8List data);
  Future<void> addLocalFile(String zipPath, String filePath);
  Future<void> finish();
}

class _RustZipSink implements ArchiveSink {
  final rust.Zip _zip;
  final String? _password;

  _RustZipSink(this._zip, [this._password]);

  @override
  Future<void> addBytes(String zipPath, Uint8List data) =>
      _zip.addBytes(zipPath: zipPath, data: data, password: _password);

  /// 媒体本身已是压缩格式，Stored 直存省 CPU。
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

/// 把解压后的备份目录当作「远端」——引擎的 pull 原样跑在本地文件上。
/// 写操作（租约锁 `sync.lock`）落在解压目录内，导入结束随目录一起清理。
class LocalArchiveBackend implements IRemoteSyncBackend {
  final String root;

  LocalArchiveBackend(this.root);

  File _file(String key) => File(p.join(root, key));

  @override
  String get displayName => '本地备份';

  @override
  bool get isReady => true;

  @override
  String? get persistentBackendId => null;

  /// 不参与 provider 注册 / KV 配置，任何读取都是用错了地方。
  @override
  SyncProviderType get type =>
      throw UnsupportedError('LocalArchiveBackend 没有 provider 类型');

  @override
  Future<String?> testConnection() async => null;

  @override
  Future<Uint8List?> readObject(String key) async {
    final file = _file(key);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  // 归档就摊在本地文件系统上，key 直接映射到真实路径，文件直通就是一次 copy ——
  // 不开的话导入备份 / 局域网接收会把每个媒体整份读进 Dart 堆，而媒体闸门默认放 8 路。
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
  Future<String> statObject(String key) async {
    final file = _file(key);
    if (!await file.exists()) return '';
    return (await file.lastModified()).toUtc().toIso8601String();
  }

  @override
  Future<SyncReport> pushAll() => throw UnimplementedError();

  @override
  Future<SyncReport> pullAll() => throw UnimplementedError();

  @override
  Future<SyncReport> syncAll() => throw UnimplementedError();
}
