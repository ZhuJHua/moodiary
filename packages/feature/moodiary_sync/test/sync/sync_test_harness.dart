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
import 'package:moodiary_sync/src/data/secure_options.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_cancellation.dart';
import 'package:moodiary_sync/src/data/sync_key_manager.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';
import 'package:moodiary_sync/src/data/sync_stores.dart';

final class FakeRemoteBackend implements IRemoteSyncBackend {
  FakeRemoteBackend({
    this.backendId = 'webdav',
    Map<String, Uint8List>? objects,
  }) : objects = objects ?? {};

  final String backendId;

  final Map<String, Uint8List> objects;

  final List<String> ops = [];

  void Function(String op, String key)? beforeOp;

  bool conditionalPutHonored = true;

  static const String _mtime = '2026-01-01T00:00:00.000Z';

  @override
  SyncProviderType get type => backendId == 's3' ? .s3 : .webdav;

  @override
  String? get persistentBackendId => backendId;

  @override
  String get displayName => 'Fake($backendId)';

  @override
  Future<bool> isReady() async => true;

  @override
  SyncException get notReadyError => const SyncException('fake not ready');

  @override
  Future<List<String>> savedOptions() async => const [];

  @override
  Future<void> saveOptions(List<String> options) async {}

  @override
  Future<void> clearOptions() async {}

  @override
  Future<void> testConnection() async {}

  @override
  Future<Uint8List?> readObject(String key) async {
    ops.add('read $key');
    beforeOp?.call('read', key);
    return objects[key];
  }

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

  int opCount(String op, [String? keyContains]) => ops
      .where(
        (o) =>
            o.startsWith('$op ') &&
            (keyContains == null || o.contains(keyContains)),
      )
      .length;

  bool hasObject(String key) => objects.containsKey(key);

  SyncManifest? manifest() {
    final bytes = objects[SyncKeys.manifestPath];
    if (bytes == null) return null;
    return .fromJson(jsonDecode(utf8.decode(bytes)));
  }

  Map<String, dynamic>? diaryJson(String id) {
    final bytes = objects[SyncKeys.diaryObjectPath(id)];
    if (bytes == null) return null;
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }
}

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

final class FakeDiaryStore implements SyncDiaryStore {
  final Map<String, Diary> diaries = {};
  final FakeTombstoneStore tombstones;

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

  final Map<String, bool> writeOrigins = {};

  @override
  Future<void> insertADiary(Diary diary, {bool fromSync = false}) async {
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

final class FakeCategoryStore implements SyncCategoryStore {
  final Map<String, Category> categories = {};
  final FakeTombstoneStore tombstones;

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

final class FakePlaceStore implements SyncPlaceStore {
  final Map<String, Place> places = {};
  final FakeTombstoneStore tombstones;

  bool insertSucceeds = true;

  FakePlaceStore([
    Iterable<Place> seed = const [],
    FakeTombstoneStore? tombstones,
  ]) : tombstones = tombstones ?? FakeTombstoneStore() {
    for (final p in seed) {
      places[p.id] = p;
    }
  }

  @override
  Future<List<Place>> getAllPlacesForSync() async => places.values.toList();

  @override
  Future<Place?> getPlaceById(String id) async => places[id];

  @override
  Future<Place?> getPlaceByName(String name) async =>
      places.values.where((p) => p.name == name).firstOrNull;

  @override
  Future<void> insertAPlace(Place place, {bool fromSync = false}) async {
    if (!insertSucceeds) throw StateError('injected insert failure');
    places[place.id] = place;
    tombstones.rows.remove(SyncTombstone.placeKey(place.id));
  }

  @override
  Future<SyncTombstone> tombstonePlace(
    String id, {
    bool fromSync = false,
  }) async {
    places.remove(id);
    final row = SyncTombstone.forPlace(id, at: .timestamp());
    tombstones.rows[row.key] = row;
    return row;
  }
}

final class FakeMediaInfoStore implements SyncMediaInfoStore {
  final Map<String, MediaInfo> mediaInfos = {};
  final FakeTombstoneStore tombstones;

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

final class FakeMediaFiles implements SyncMediaFiles {
  final Map<String, Uint8List> files = {};
  final List<String> ops = [];

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

  @override
  String? realPath(String type, String filename) => null;
}

Future<({MemoryKVStorage kv, MemorySecureKVStorage secure, SyncLogger logger})>
setUpSyncEnv() async {
  await getIt.reset();
  final kv = MemoryKVStorage();
  final secure = MemorySecureKVStorage();
  getIt.registerSingleton<IKVStorage>(kv);
  getIt.registerSingleton<ISecureKVStorage>(secure);
  final logger = await SyncLogger.create();
  getIt.registerSingleton<SyncLogger>(logger);
  getIt.registerLazySingleton<SecureOptions>(
    () => SecureOptions(.webDavOption),
    instanceName: SyncProviderIds.webdav,
  );
  getIt.registerLazySingleton<SecureOptions>(
    () => SecureOptions(.s3Option),
    instanceName: SyncProviderIds.s3,
  );
  getIt.registerLazySingleton<IRemoteSyncBackend>(
    () => WebDavSyncBackend(
      getIt<SecureOptions>(instanceName: SyncProviderIds.webdav),
    ),
    instanceName: SyncProviderIds.webdav,
  );
  getIt.registerLazySingleton<IRemoteSyncBackend>(
    () => S3SyncBackend(getIt<SecureOptions>(instanceName: SyncProviderIds.s3)),
    instanceName: SyncProviderIds.s3,
  );
  getIt.registerSingleton<OpenDiaryRegistry>(OpenDiaryRegistry());
  getIt.registerSingleton<SyncPendingTracker>(SyncPendingTracker());
  getIt.registerSingleton<SyncDirtyTracker>(SyncDirtyTracker());
  getIt.registerSingleton<SyncCancellation>(SyncCancellation());
  MoodiaryKVs.syncDeviceId.set('test-device');
  RemoteLease.resetCasProbeCache();
  SyncKeyManager.resetForTest();
  return (kv: kv, secure: secure, logger: logger);
}

Future<void> tearDownSyncEnv() async {
  RemoteLease.resetCasProbeCache();
  SyncKeyManager.resetForTest();
  await getIt.reset();
}

Future<void> configureBackend(SyncProviderType type) async {
  switch (type) {
    case .webdav:
      await getIt<IRemoteSyncBackend>(instanceName: type.value)
          .saveOptions(['https://dav.example', 'user', 'pass']);
    case .s3:
      await getIt<IRemoteSyncBackend>(instanceName: type.value)
          .saveOptions(['https://s3.example', '', 'ak', 'sk', 'bucket', '1']);
  }
}

final DateTime kBaseTime = .utc(2026, 1, 1);

DateTime atMs(int millisOffset) =>
    kBaseTime.add(Duration(milliseconds: millisOffset));

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
    mood: .neutral,
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
