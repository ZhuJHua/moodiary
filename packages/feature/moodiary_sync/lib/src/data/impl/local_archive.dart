import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_rust/foundation.dart' as rust;
import 'package:moodiary_sync/src/data/archive_apply.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/incremental_engine.dart';
import 'package:moodiary_sync/src/data/media_refs.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_stores.dart';
import 'package:path/path.dart' as p;

/// 本地备份归档 —— 导出/导入 zip，包内布局与远端同步完全一致：
/// `manifest.json` + `diary/<id>.json` + `category/<id>.json` +
/// `mediainfo/<type>/<fileName>.json` + `media/<type>/<filename>`，
/// 一律明文（本地压缩包不加密）。
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
      final mediaInfos = await RepoSyncMediaInfoStore()
          .getAllMediaInfosForSync();
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
      final mediaInfos = await RepoSyncMediaInfoStore()
          .getAllMediaInfosForSync();
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

  /// 局域网接收方：把本机数据投影成 manifest，供发送方算增量。
  static Future<SyncManifest> buildLocalManifest() async => buildManifest(
    diaries: await RepoSyncDiaryStore().getAllDiaries(),
    categories: await RepoSyncCategoryStore().getAllCategoriesForSync(),
    mediaInfos: await RepoSyncMediaInfoStore().getAllMediaInfosForSync(),
    tombstones: await RepoSyncTombstoneStore().getAll(),
    mediaBaseDir: PlatformService.get().applicationSupportPath,
  );

  /// 把本机快照投影成 manifest（entries 含 tombstone；媒体引用只列本地真实存在
  /// 的文件，与 push「不谎报存在」同规则）。导出与局域网接收方共用。
  static Future<SyncManifest> buildManifest({
    required List<Diary> diaries,
    required List<Category> categories,
    List<MediaInfo> mediaInfos = const [],
    required List<SyncTombstone> tombstones,
    required String mediaBaseDir,
  }) async {
    final entries = <String, ManifestEntry>{};
    // 墓碑键（`d:`/`c:`/`m:` 前缀）与活跃行按不变量互斥，覆盖顺序无关紧要。
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

  /// 按远端布局把快照写入 [sink]，返回写入的 manifest 条目数。
  ///
  /// [remote] 非 null 时做增量（局域网发送）：写比对方新的条目（LWW，含 tombstone；
  /// 对方从未有过的条目不发 tombstone），**以及时间戳相同但对方缺媒体的条目**——
  /// 后者是重传能补回丢失媒体的唯一途径。对方已有的媒体不进包，但仍留在条目的
  /// media 列表里（列表描述日记引用了什么，导入端对已存在文件本就跳过下载）。
  /// 过滤只是省带宽：导入端的 engine.pull 才是正确性闸门。
  @visibleForTesting
  static Future<int> writeArchive({
    required ArchiveSink sink,
    required List<Diary> diaries,
    required List<Category> categories,
    List<MediaInfo> mediaInfos = const [],
    required List<SyncTombstone> tombstones,
    required String mediaBaseDir,
    SyncManifest? remote,
  }) async {
    const cipher = SyncCipher.plaintext;
    final manifest = await buildManifest(
      diaries: diaries,
      categories: categories,
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
      // 时间戳相同也可能要发：对方 JSON 落库成功而媒体拷贝失败（磁盘写满等），
      // manifest 只列磁盘上真实存在的文件，缺口在这里看得见。只比时间戳的话重传
      // 会报「对方已是最新」，丢掉的图/音再也补不回来，而用户往往据此抹掉旧机。
      final remoteRefs = remoteEntry.media.toSet();
      return entry.media.any((ref) => !remoteRefs.contains(ref));
    }

    final included = <String, ManifestEntry>{
      for (final e in manifest.entries.entries)
        if (include(e.key, e.value)) e.key: e.value,
    };

    final diaryById = {for (final d in diaries) d.id: d};
    final categoryById = {for (final c in categories) c.id: c};
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

  /// [policy] 见 [ArchiveApplyPolicy]。「从备份恢复」传 [RestorePolicy]（只增不删）；
  /// 局域网接收是设备间搬运，保持默认的 [SyncPullPolicy]（删除照常传播）。
  static Future<SyncReport> import(
    String zipPath, {
    String? password,
    rust.CancelToken? cancel,
    ArchiveApplyPolicy policy = const SyncPullPolicy(),
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
      return await importDirectory(extractDir.path, policy: policy);
    } finally {
      try {
        await extractDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// 旧版备份包的判据：**根目录下任意 `*.isar`**。
  ///
  /// 老包是 `<毫秒戳>.isar` + `image/ audio/ video/ font/`（v2.7.3 的 `zipFile`
  /// 如此，2.6.0 同构），文件名按导出时刻命名、**没有固定名也没有 `database/`
  /// 这一层**。此前按 `database/default.isar` 探测的是运行期数据目录的布局，对
  /// 任何真实旧包都不成立，于是它们全部落到「不是备份文件」，用户以为自己选错了
  /// 文件反复重试。为兼容手工拷数据目录打的包，那条老路径也一并认。
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
    SyncMediaInfoStore? mediaInfoStore,
    SyncTombstoneStore? tombstoneStore,
    SyncMediaFiles? mediaFiles,
    Future<SyncCipher> Function()? cipherProvider,
    int? concurrency,
    ArchiveApplyPolicy policy = const SyncPullPolicy(),
  }) async {
    if (!await File(p.join(dir, SyncKeys.manifestPath)).exists()) {
      // 2.8.0 之前的导出**有意不支持导入**（已拍板）：识别出老布局时给出明确指引，
      // 而不是笼统的「不是备份文件」。
      if (await _looksLikeLegacyBackup(dir)) {
        throw SyncException(l10n.sync.errLegacyBackup);
      }
      throw SyncException(l10n.sync.errNotBackup);
    }
    // 直接用 [ArchiveApplier]，不经 [IncrementalSyncEngine]：恢复不需要远端租约锁
    // （为一个解压出来的临时目录抢锁，防的是不存在的并发设备）、不需要 keyfile 补传
    // 前奏、也不推进「上次同步时间」。同步专属的东西留在引擎里。
    //
    // **但进程内互斥锁要**：它挡的是本机自己的并发。少了它，恢复能与云端 push 交错，
    // push 会把恢复尚未插回的那批墓碑推成远端删除，反过来把刚恢复的日记全网抹掉。
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
        mediaInfoStore: mediaInfoStore,
        tombstoneStore: tombstoneStore,
        mediaFiles: mediaFiles,
        cipherProvider: cipher,
        concurrency: concurrency ?? 4,
      ).apply(SyncManifest.fromJson(decoded)),
    );
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
/// 只实现 [RemoteObjectStore]：它只当对象源用，不承担 push/pull 编排。
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
  Future<String?> statObject(String key) async {
    final file = _file(key);
    if (!await file.exists()) return null;
    return (await file.lastModified()).toUtc().toIso8601String();
  }
}
