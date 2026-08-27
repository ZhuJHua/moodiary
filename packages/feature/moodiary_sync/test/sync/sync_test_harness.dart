import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:moodiary_sync/src/data/impl/s3_sync.dart';
import 'package:moodiary_sync/src/data/impl/webdav_sync.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/model/sync_provider.dart';
import 'package:moodiary_sync/src/data/remote_lease.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_cancellation.dart';
import 'package:moodiary_sync/src/data/sync_key_manager.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';
import 'package:moodiary_sync/src/data/sync_registry.dart';
import 'package:moodiary_sync/src/data/sync_stores.dart';

/// 同步引擎单测脚手架：把引擎对 KV / 后端 / 本地存储 / cipher 的依赖全部替换成
/// 内存假实现，不触碰 Isar / 文件系统 / Rust FFI / 网络，纯确定性运行。

// ─────────────────────── remote backend ───────────────────────

/// 内存远端后端，实现 [IRemoteSyncBackend]。支持故障注入（[beforeOp]）与操作记录。
final class FakeRemoteBackend implements IRemoteSyncBackend {
  FakeRemoteBackend({
    this.backendId = 'webdav',
    Map<String, Uint8List>? objects,
  }) : objects = objects ?? {};

  final String backendId;

  /// 远端对象表（key 为相对路径，如 `manifest.json` / `diary/x.json` / `media/...`）。
  final Map<String, Uint8List> objects;

  /// 所有操作的有序记录：`'<op> <key>'`，供断言上传顺序 / 调用次数。
  final List<String> ops = [];

  /// 每个操作开始时回调；抛异常即模拟该操作失败。op ∈ read/write/create/delete/stat。
  void Function(String op, String key)? beforeOp;

  /// false = 模拟不执行 `If-None-Match:*` 的服务器：已存在也覆盖写并返回 true。
  bool conditionalPutHonored = true;

  /// 固定的 Last-Modified，仅需非空字符串表示「远端存在」。
  static const String _mtime = '2026-01-01T00:00:00.000Z';

  @override
  SyncProviderType get type => backendId == 's3' ? .s3 : .webdav;

  @override
  String? get persistentBackendId => backendId;

  @override
  String get displayName => 'Fake($backendId)';

  @override
  bool get isReady => true;

  @override
  Future<String?> testConnection() async => null;

  @override
  Future<Uint8List?> readObject(String key) async {
    ops.add('read $key');
    beforeOp?.call('read', key);
    return objects[key];
  }

  /// 生产上 S3/WebDAV 都是 true，引擎会走 _downloadMediaByFile / _uploadMediaByFile ——
  /// 替身也必须支持，否则那条分支在测试里恒不执行。
  @override
  bool get supportsFileObjects => true;

  @override
  Future<bool> readObjectToFile(String key, String filePath) async {
    ops.add('read $key');
    beforeOp?.call('read', key);
    final bytes = objects[key];
    if (bytes == null) return false;
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return true;
  }

  @override
  Future<void> writeObjectFile(String key, String filePath) async {
    ops.add('write $key');
    beforeOp?.call('write', key);
    objects[key] = await File(filePath).readAsBytes();
  }

  @override
  Future<void> writeObject(String key, Uint8List bytes) async {
    ops.add('write $key');
    beforeOp?.call('write', key);
    objects[key] = bytes;
  }

  @override
  Future<bool> tryCreateExclusive(String key, Uint8List bytes) async {
    ops.add('create $key');
    beforeOp?.call('create', key);
    if (objects.containsKey(key) && conditionalPutHonored) return false;
    objects[key] = bytes;
    return true;
  }

  @override
  Future<void> deleteObject(String key) async {
    ops.add('delete $key');
    beforeOp?.call('delete', key);
    objects.remove(key);
  }

  @override
  Future<String?> statObject(String key) async {
    ops.add('stat $key');
    beforeOp?.call('stat', key);
    return objects.containsKey(key) ? _mtime : null;
  }

  @override
  Future<SyncReport> pushAll() => throw UnimplementedError();
  @override
  Future<SyncReport> pullAll() => throw UnimplementedError();
  @override
  Future<SyncReport> syncAll() => throw UnimplementedError();

  // ── 测试辅助 ──

  int opCount(String op, [String? keyContains]) => ops
      .where(
        (o) =>
            o.startsWith('$op ') &&
            (keyContains == null || o.contains(keyContains)),
      )
      .length;

  bool hasObject(String key) => objects.containsKey(key);

  /// 解出远端 manifest（明文）；不存在返回 null。
  SyncManifest? manifest() {
    final bytes = objects[SyncKeys.manifestPath];
    if (bytes == null) return null;
    return .fromJson(jsonDecode(utf8.decode(bytes)));
  }

  /// 解出远端某 diary JSON（明文）。
  Map<String, dynamic>? diaryJson(String id) {
    final bytes = objects[SyncKeys.diaryObjectPath(id)];
    if (bytes == null) return null;
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }
}

// ─────────────────────── local stores ───────────────────────

/// 内存墓碑表，实现 [SyncTombstoneStore]。`rows` 以 manifest 键（`d:`/`c:`）为键。
final class FakeTombstoneStore implements SyncTombstoneStore {
  final Map<String, SyncTombstone> rows = {};
  final List<String> calls = [];

  FakeTombstoneStore([Iterable<SyncTombstone> seed = const []]) {
    for (final t in seed) {
      rows[t.key] = t;
    }
  }

  @override
  Future<List<SyncTombstone>> getAll() async => rows.values.toList();

  @override
  Future<SyncTombstone?> getByKey(String key) async => rows[key];

  @override
  Future<void> putAll(List<SyncTombstone> list) async {
    for (final t in list) {
      calls.add('put ${t.key}');
      rows[t.key] = t;
    }
  }

  @override
  Future<void> deleteByKeys(List<String> keys) async {
    for (final key in keys) {
      if (rows.remove(key) != null) calls.add('delete $key');
    }
  }
}

/// 内存日记仓库，实现 [SyncDiaryStore]。`diaries` 以业务 id 为键；与
/// [FakeTombstoneStore] 镜像真实仓储的事务不变量（insert 清墓碑、tombstone
/// 删行 + 落墓碑）——引擎与 store 须共享同一 tombstones 实例。
final class FakeDiaryStore implements SyncDiaryStore {
  final Map<String, Diary> diaries = {};
  final FakeTombstoneStore tombstones;

  /// 引擎调用记录，供断言（如确认 pull 墓碑走的是 tombstoneDiary）。
  final List<String> calls = [];

  FakeDiaryStore([
    Iterable<Diary> seed = const [],
    FakeTombstoneStore? tombstones,
  ]) : tombstones = tombstones ?? FakeTombstoneStore() {
    for (final d in seed) {
      diaries[d.id] = d;
    }
  }

  @override
  Future<List<Diary>> getAllDiaries() async {
    calls.add('getAll');
    return diaries.values.toList();
  }

  @override
  Future<Diary?> getDiaryByBusinessId(String id) async {
    calls.add('getById $id');
    return diaries[id];
  }

  /// 每次写入携带的 fromSync 标记（断言云 pull 与归档导入的事件来源）。
  final Map<String, bool> writeOrigins = {};

  @override
  Future<void> insertADiary(
    Diary diary, {
    bool fromSync = false,
  }) async {
    calls.add('insert ${diary.id}');
    writeOrigins[diary.id] = fromSync;
    diaries[diary.id] = diary;
    tombstones.rows.remove(SyncTombstone.diaryKey(diary.id));
  }

  @override
  Future<SyncTombstone> tombstoneDiary(
    Diary diary, {
    bool fromSync = false,
  }) async {
    calls.add('tombstone ${diary.id}');
    writeOrigins[diary.id] = fromSync;
    diaries.remove(diary.id);
    final row = SyncTombstone.forDiary(diary.id, at: .timestamp());
    tombstones.rows[row.key] = row;
    return row;
  }
}

/// 内存分类仓库，实现 [SyncCategoryStore]。
final class FakeCategoryStore implements SyncCategoryStore {
  final Map<String, Category> categories = {};
  final FakeTombstoneStore tombstones;

  /// 写入返回 false 用于模拟仓库写失败。
  bool insertSucceeds = true;

  FakeCategoryStore([
    Iterable<Category> seed = const [],
    FakeTombstoneStore? tombstones,
  ]) : tombstones = tombstones ?? FakeTombstoneStore() {
    for (final c in seed) {
      categories[c.id] = c;
    }
  }

  @override
  Future<List<Category>> getAllCategoriesForSync() async =>
      categories.values.toList();

  @override
  Future<Category?> getCategoryById(String id) async => categories[id];

  @override
  Future<void> insertACategory(
    Category category, {
    bool fromSync = false,
  }) async {
    // 与仓储一致：失败抛异常（由引擎条目级 catch 计 failed）。
    if (!insertSucceeds) throw StateError('injected insert failure');
    categories[category.id] = category;
    tombstones.rows.remove(SyncTombstone.categoryKey(category.id));
  }

  @override
  Future<SyncTombstone> tombstoneCategory(
    String id, {
    bool fromSync = false,
  }) async {
    categories.remove(id);
    final row = SyncTombstone.forCategory(id, at: .timestamp());
    tombstones.rows[row.key] = row;
    return row;
  }
}

/// 内存媒体元数据仓库，实现 [SyncMediaInfoStore]。
final class FakeMediaInfoStore implements SyncMediaInfoStore {
  final Map<String, MediaInfo> mediaInfos = {};
  final FakeTombstoneStore tombstones;

  /// 写入返回 false 用于模拟仓库写失败。
  bool insertSucceeds = true;

  FakeMediaInfoStore([
    Iterable<MediaInfo> seed = const [],
    FakeTombstoneStore? tombstones,
  ]) : tombstones = tombstones ?? FakeTombstoneStore() {
    for (final m in seed) {
      mediaInfos[m.fileName] = m;
    }
  }

  @override
  Future<List<MediaInfo>> getAllMediaInfosForSync() async =>
      mediaInfos.values.toList();

  @override
  Future<MediaInfo?> getMediaInfoByFileName(String fileName) async =>
      mediaInfos[fileName];

  @override
  Future<void> insertAMediaInfo(
    MediaInfo mediaInfo, {
    bool fromSync = false,
  }) async {
    // 与仓储一致：失败抛异常（由引擎条目级 catch 计 failed）。
    if (!insertSucceeds) throw StateError('injected insert failure');
    mediaInfos[mediaInfo.fileName] = mediaInfo;
    tombstones.rows.remove(SyncTombstone.mediaInfoKey(mediaInfo.fileName));
  }

  @override
  Future<SyncTombstone> tombstoneMediaInfo(
    String fileName, {
    bool fromSync = false,
  }) async {
    mediaInfos.remove(fileName);
    final row = SyncTombstone.forMediaInfo(fileName, at: .timestamp());
    tombstones.rows[row.key] = row;
    return row;
  }
}

/// 内存媒体文件，实现 [SyncMediaFiles]。`files` 以 `<type>/<filename>` 为键。
final class FakeMediaFiles implements SyncMediaFiles {
  final Map<String, Uint8List> files = {};
  final List<String> ops = [];

  /// 删除某文件时回调（在实际删除前），用于断言删除发生的时序。
  void Function(String type, String filename)? onDelete;

  FakeMediaFiles([Map<String, Uint8List>? seed]) {
    if (seed != null) files.addAll(seed);
  }

  String _k(String type, String filename) => '$type/$filename';

  void put(String type, String filename, [List<int>? bytes]) {
    files[_k(type, filename)] = .fromList(bytes ?? utf8.encode(filename));
  }

  @override
  Future<bool> exists(String type, String filename) async =>
      files.containsKey(_k(type, filename));

  @override
  Future<Uint8List> read(String type, String filename) async {
    ops.add('read ${_k(type, filename)}');
    final bytes = files[_k(type, filename)];
    if (bytes == null) throw StateError('missing media ${_k(type, filename)}');
    return bytes;
  }

  @override
  Future<void> write(String type, String filename, Uint8List bytes) async {
    ops.add('write ${_k(type, filename)}');
    files[_k(type, filename)] = bytes;
  }

  @override
  Future<void> delete(String type, String filename) async {
    ops.add('delete ${_k(type, filename)}');
    onDelete?.call(type, filename);
    files.remove(_k(type, filename));
  }

  @override
  Future<void> cleanUpReplaced(Diary oldDiary, Diary newDiary) async {
    Future<void> drop(
      List<String> oldNames,
      List<String> newNames,
      String t,
    ) async {
      for (final name in oldNames) {
        if (!newNames.contains(name)) await delete(t, name);
      }
    }

    await drop(oldDiary.imageName, newDiary.imageName, 'image');
    await drop(oldDiary.audioName, newDiary.audioName, 'audio');
    await drop(oldDiary.videoName, newDiary.videoName, 'video');
  }

  /// 纯内存实现，Rust 看不见 —— 引擎据此回退字节路径。路径式分支的覆盖见
  /// media_file_path_test.dart，那里用生产的 DiskSyncMediaFiles 配临时目录。
  @override
  String? realPath(String type, String filename) => null;
}

// ─────────────────────── env setup ───────────────────────

/// 注册内存 KV / SecureKV / SyncLogger 到 get_it，预置 deviceId 避免 RemoteLease
/// 走 uuidV4()（Rust）。每个测试 setUp 调用，tearDown 调 [tearDownSyncEnv]。
Future<({MemoryKVStorage kv, MemorySecureKVStorage secure, SyncLogger logger})>
setUpSyncEnv() async {
  await getIt.reset();
  final kv = MemoryKVStorage();
  final secure = MemorySecureKVStorage();
  getIt.registerSingleton<IKVStorage>(kv);
  getIt.registerSingleton<ISecureKVStorage>(secure);
  // SyncLogger.create() 内部访问 PlatformService 失败会降级为纯内存模式，测试安全。
  final logger = await SyncLogger.create();
  getIt.registerSingleton<SyncLogger>(logger);
  // prod 由组合根在装载后显式 reload；测试注新构造的空持有者，未 reload 前
  // hasBackend 为 false。
  getIt.registerSingleton<RemoteSyncRegistry>(RemoteSyncRegistry());
  // 预置设备 id：RemoteLease 无此值时会调 uuidV4()（Rust），测试环境不可用。
  MoodiaryKVs.syncDeviceId.set('test-device');
  SyncCancellation.instance.reset();
  SyncPendingTracker.instance.clear();
  RemoteLease.resetCasProbeCache();
  SyncKeyManager.resetForTest();
  return (kv: kv, secure: secure, logger: logger);
}

Future<void> tearDownSyncEnv() async {
  SyncCancellation.instance.reset();
  SyncPendingTracker.instance.clear();
  RemoteLease.resetCasProbeCache();
  SyncKeyManager.resetForTest();
  await getIt.reset();
}

/// 把后端标记为「已配置」，使 [configuredCloudBackendIds] 把它计入。
Future<void> configureBackend(SyncProviderType type) async {
  switch (type) {
    case .webdav:
      await WebDavSyncBackend.options.save([
        'https://dav.example',
        'user',
        'pass',
      ]);
    case .s3:
      await S3SyncBackend.options.save([
        'https://s3.example',
        '',
        'ak',
        'sk',
        'bucket',
        '1',
      ]);
  }
}

// ─────────────────────── model builders ───────────────────────

/// 固定基准时刻（毫秒），各测试用偏移构造可比较的 lastModified。
final DateTime kBaseTime = .utc(2026, 1, 1);

DateTime atMs(int millisOffset) =>
    kBaseTime.add(Duration(milliseconds: millisOffset));

/// 构造一条 diary（直接给字面 id，字段全部可控）。
Diary buildDiary({
  required String id,
  int modifiedMs = 0,
  bool show = true,
  String? categoryId,
  String title = '',
  String content = '',
  List<String> images = const [],
  List<String> audios = const [],
  List<String> videos = const [],
}) {
  final ts = atMs(modifiedMs);
  return Diary(
    id: id,
    categoryId: categoryId,
    title: title,
    content: content,
    contentText: content,
    time: ts,
    lastModified: ts,
    show: show,
    mood: 0,
    imageName: images,
    audioName: audios,
    videoName: videos,
    tags: const [],
    type: 'tiptap',
  );
}

Category buildCategory({
  required String id,
  int modifiedMs = 0,
  String name = 'cat',
  String? parentId,
}) {
  return Category(
    id: id,
    categoryName: name,
    lastModified: atMs(modifiedMs),
    parentId: parentId,
  );
}

/// 构造一条日记墓碑（删除时刻用 atMs 偏移表示，便于 LWW 断言）。
SyncTombstone buildDiaryTombstone(
  String id, {
  int modifiedMs = 0,
  List<String> pushed = const [],
}) {
  return SyncTombstone(
    key: SyncTombstone.diaryKey(id),
    timeMs: atMs(modifiedMs).millisecondsSinceEpoch,
    pushedBackends: pushed,
  );
}

SyncTombstone buildCategoryTombstone(
  String id, {
  int modifiedMs = 0,
  List<String> pushed = const [],
}) {
  return SyncTombstone(
    key: SyncTombstone.categoryKey(id),
    timeMs: atMs(modifiedMs).millisecondsSinceEpoch,
    pushedBackends: pushed,
  );
}

MediaInfo buildMediaInfo({
  required String fileName,
  int modifiedMs = 0,
  String? name,
  int? durationMs,
}) {
  return MediaInfo(
    fileName: fileName,
    name: name,
    durationMs: durationMs,
    lastModified: atMs(modifiedMs),
  );
}

SyncTombstone buildMediaInfoTombstone(
  String fileName, {
  int modifiedMs = 0,
  List<String> pushed = const [],
}) {
  return SyncTombstone(
    key: SyncTombstone.mediaInfoKey(fileName),
    timeMs: atMs(modifiedMs).millisecondsSinceEpoch,
    pushedBackends: pushed,
  );
}
