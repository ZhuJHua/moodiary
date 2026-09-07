import 'dart:typed_data';

import 'package:fast_image/fast_image.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_sync/src/data/media_refs.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:path/path.dart' as p;

abstract interface class SyncDiaryStore {
  Future<List<Diary>> getAllDiaries();
  Future<Diary?> getDiaryByBusinessId(String id);

  Future<void> insertADiary(Diary diary, {bool fromSync = false});

  Future<SyncTombstone> tombstoneDiary(Diary diary, {bool fromSync = false});
}

abstract interface class SyncCategoryStore {
  Future<List<Category>> getAllCategoriesForSync();
  Future<Category?> getCategoryById(String id);

  Future<void> insertACategory(Category category, {bool fromSync = false});

  Future<SyncTombstone> tombstoneCategory(String id, {bool fromSync = false});
}

abstract interface class SyncPlaceStore {
  Future<List<Place>> getAllPlacesForSync();
  Future<Place?> getPlaceById(String id);
  Future<Place?> getPlaceByName(String name);

  Future<void> insertAPlace(Place place, {bool fromSync = false});

  Future<SyncTombstone> tombstonePlace(String id, {bool fromSync = false});
}

abstract interface class SyncMediaInfoStore {
  Future<List<MediaInfo>> getAllMediaInfosForSync();
  Future<MediaInfo?> getMediaInfoByFileName(String fileName);

  Future<void> insertAMediaInfo(MediaInfo mediaInfo, {bool fromSync = false});

  Future<SyncTombstone> tombstoneMediaInfo(
    String fileName, {
    bool fromSync = false,
  });
}

abstract interface class SyncTombstoneStore {
  Future<List<SyncTombstone>> getAll();
  Future<SyncTombstone?> getByKey(String key);
  Future<void> putAll(List<SyncTombstone> rows);
  Future<void> deleteByKeys(List<String> keys);
}

abstract interface class SyncMediaFiles {
  Future<bool> exists(String type, String filename);
  Future<Uint8List> read(String type, String filename);
  Future<void> write(String type, String filename, Uint8List bytes);
  Future<void> delete(String type, String filename);

  String? realPath(String type, String filename);

  Future<void> cleanUpReplaced(Diary oldDiary, Diary newDiary);
}

class RepoSyncDiaryStore implements SyncDiaryStore {
  late final _repo = getIt<DiaryRepository>();

  @override
  Future<List<Diary>> getAllDiaries() => _repo.getAllDiaries();

  @override
  Future<Diary?> getDiaryByBusinessId(String id) =>
      _repo.getDiaryByBusinessId(id);

  @override
  Future<void> insertADiary(Diary diary, {bool fromSync = false}) =>
      _repo.insertADiary(diary, fromSync: fromSync);

  @override
  Future<SyncTombstone> tombstoneDiary(Diary diary, {bool fromSync = false}) =>
      _repo.tombstoneDiaryForSync(diary, fromSync: fromSync);
}

class RepoSyncCategoryStore implements SyncCategoryStore {
  late final _repo = getIt<CategoryRepository>();

  @override
  Future<List<Category>> getAllCategoriesForSync() => _repo.getAllCategories();

  @override
  Future<Category?> getCategoryById(String id) => _repo.getCategoryById(id);

  @override
  Future<void> insertACategory(Category category, {bool fromSync = false}) =>
      _repo.insertACategory(category, fromSync: fromSync);

  @override
  Future<SyncTombstone> tombstoneCategory(String id, {bool fromSync = false}) =>
      _repo.tombstoneCategoryForSync(id, fromSync: fromSync);
}

class RepoSyncPlaceStore implements SyncPlaceStore {
  late final _repo = getIt<PlaceRepository>();

  @override
  Future<List<Place>> getAllPlacesForSync() => _repo.getAllPlaces();

  @override
  Future<Place?> getPlaceById(String id) => _repo.getPlaceById(id);

  @override
  Future<Place?> getPlaceByName(String name) => _repo.getPlaceByName(name);

  @override
  Future<void> insertAPlace(Place place, {bool fromSync = false}) =>
      _repo.insertAPlace(place, fromSync: fromSync);

  @override
  Future<SyncTombstone> tombstonePlace(String id, {bool fromSync = false}) =>
      _repo.tombstonePlaceForSync(id, fromSync: fromSync);
}

class RepoSyncMediaInfoStore implements SyncMediaInfoStore {
  late final _repo = getIt<MediaInfoRepository>();

  @override
  Future<List<MediaInfo>> getAllMediaInfosForSync() => _repo.getAllMediaInfos();

  @override
  Future<MediaInfo?> getMediaInfoByFileName(String fileName) =>
      _repo.getMediaInfoByFileName(fileName);

  @override
  Future<void> insertAMediaInfo(MediaInfo mediaInfo, {bool fromSync = false}) =>
      _repo.insertAMediaInfo(mediaInfo, fromSync: fromSync);

  @override
  Future<SyncTombstone> tombstoneMediaInfo(
    String fileName, {
    bool fromSync = false,
  }) => _repo.tombstoneMediaInfoForSync(fileName, fromSync: fromSync);
}

class RepoSyncTombstoneStore implements SyncTombstoneStore {
  late final _repo = getIt<TombstoneRepository>();

  @override
  Future<List<SyncTombstone>> getAll() => _repo.getAll();

  @override
  Future<SyncTombstone?> getByKey(String key) => _repo.getByKey(key);

  @override
  Future<void> putAll(List<SyncTombstone> rows) => _repo.putAll(rows);

  @override
  Future<void> deleteByKeys(List<String> keys) => _repo.deleteByKeys(keys);
}

class DiskSyncMediaFiles implements SyncMediaFiles {
  DiskSyncMediaFiles({FileSystem? fileSystem, String? baseDir})
    : _fs = fileSystem ?? const LocalFileSystem(),
      _baseDir = baseDir ?? PlatformService.get().applicationSupportPath;

  final FileSystem _fs;
  final String _baseDir;

  File _file(String type, String filename) {
    _rejectPathEscape(type);
    _rejectPathEscape(filename);
    return _fs.file(p.join(_baseDir, type, filename));
  }

  static void _rejectPathEscape(String segment) {
    if (segment.isEmpty ||
        p.isAbsolute(segment) ||
        p.basename(segment) != segment) {
      throw SyncException(l10n.sync.errMediaNameInvalid(name: segment));
    }
  }

  @override
  Future<bool> exists(String type, String filename) =>
      _file(type, filename).exists();

  @override
  Future<Uint8List> read(String type, String filename) =>
      _file(type, filename).readAsBytes();

  @override
  String? realPath(String type, String filename) =>
      _fs is LocalFileSystem ? _file(type, filename).path : null;

  @override
  Future<void> write(String type, String filename, Uint8List bytes) async {
    final file = _file(type, filename);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  }

  @override
  Future<void> delete(String type, String filename) async {
    final file = _file(type, filename);
    if (await file.exists()) await file.delete();
    if (type == MediaType.image.value && _fs is LocalFileSystem) {
      await FastImageDerivatives.deleteFor(filename);
    }
  }

  @override
  Future<void> cleanUpReplaced(Diary oldDiary, Diary newDiary) async {
    Future<void> drop(
      List<String> oldNames,
      List<String> newNames,
      String type,
    ) async {
      for (final name in oldNames) {
        if (!newNames.contains(name)) await delete(type, name);
      }
    }

    await drop(oldDiary.imageName, newDiary.imageName, 'image');
    await drop(oldDiary.audioName, newDiary.audioName, 'audio');
    await drop(oldDiary.videoName, newDiary.videoName, 'video');
    for (final name in oldDiary.videoName) {
      if (newDiary.videoName.contains(name)) continue;
      final thumb = videoThumbnailName(name);
      if (thumb != null) await delete('video', thumb);
    }
  }
}
