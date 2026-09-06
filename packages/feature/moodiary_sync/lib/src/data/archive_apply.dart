import 'dart:async';
import 'dart:io';

import 'package:fast_image/fast_image.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/media_refs.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_cancellation.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';
import 'package:moodiary_sync/src/data/sync_stores.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';
import 'package:synchronized/synchronized.dart';

final _syncFamilyLock = Lock();

Future<T> runSyncExclusive<T>(Future<T> Function() body) =>
    _syncFamilyLock.synchronized(() async {
      try {
        return await body();
      } finally {
        getIt<SyncCancellation>().reset();
      }
    });

abstract class ArchiveApplyPolicy {
  const ArchiveApplyPolicy();

  bool get appliesTombstones;

  bool get localTombstonesBlockWrite;
}

class SyncPullPolicy extends ArchiveApplyPolicy {
  const SyncPullPolicy();

  @override
  bool get appliesTombstones => true;

  @override
  bool get localTombstonesBlockWrite => true;
}

class RestorePolicy extends ArchiveApplyPolicy {
  const RestorePolicy();

  @override
  bool get appliesTombstones => false;

  @override
  bool get localTombstonesBlockWrite => false;
}

class ArchiveApplier {
  final RemoteObjectStore backend;
  final ArchiveApplyPolicy policy;
  final SyncLogger _logger;
  final SyncDiaryStore _diaryStore;
  final SyncCategoryStore _categoryStore;
  final SyncPlaceStore _placeStore;
  final SyncMediaInfoStore _mediaInfoStore;
  final SyncTombstoneStore _tombstoneStore;
  final SyncMediaFiles _mediaFiles;
  final Future<SyncCipher> Function() _cipherProvider;
  final int concurrency;
  final Pool _mediaGate;

  factory ArchiveApplier(
    RemoteObjectStore backend, {
    required ArchiveApplyPolicy policy,
    SyncLogger? logger,
    SyncDiaryStore? diaryStore,
    SyncCategoryStore? categoryStore,
    SyncPlaceStore? placeStore,
    SyncMediaInfoStore? mediaInfoStore,
    SyncTombstoneStore? tombstoneStore,
    SyncMediaFiles? mediaFiles,
    Future<SyncCipher> Function()? cipherProvider,
    int concurrency = 4,
    OpenDiaryRegistry? openDiaries,
    SyncCancellation? cancellation,
    SyncPendingTracker? pending,
    SyncTrigger? trigger,
  }) => ArchiveApplier._(
    backend,
    policy,
    concurrency,
    logger ?? getIt<SyncLogger>(),
    diaryStore ?? RepoSyncDiaryStore(),
    categoryStore ?? RepoSyncCategoryStore(),
    placeStore ?? RepoSyncPlaceStore(),
    mediaInfoStore ?? RepoSyncMediaInfoStore(),
    tombstoneStore ?? RepoSyncTombstoneStore(),
    mediaFiles ?? DiskSyncMediaFiles(),
    cipherProvider ?? SyncCipher.current,
    openDiaries ?? getIt<OpenDiaryRegistry>(),
    cancellation ?? getIt<SyncCancellation>(),
    pending ?? getIt<SyncPendingTracker>(),
    trigger,
  );

  ArchiveApplier._(
    this.backend,
    this.policy,
    this.concurrency,
    this._logger,
    this._diaryStore,
    this._categoryStore,
    this._placeStore,
    this._mediaInfoStore,
    this._tombstoneStore,
    this._mediaFiles,
    this._cipherProvider,
    this._openDiaries,
    this._cancellation,
    this._pending,
    this._trigger,
  ) : _mediaGate = Pool(concurrency);

  final OpenDiaryRegistry _openDiaries;
  final SyncCancellation _cancellation;
  final SyncPendingTracker _pending;

  final SyncTrigger? _trigger;

  int _mediaFailed = 0;
  int _mediaDownloaded = 0;

  SyncCipher? _cipherCache;

  Future<SyncCipher> _cipher() async =>
      _cipherCache ??= await _cipherProvider();

  bool get _restoring => !policy.localTombstonesBlockWrite;

  Map<String, Object?> _backendPayload() => {
    'backend': backend.displayName,
    'backendId': backend.persistentBackendId ?? 'transient',
    if (_trigger != null) 'trigger': _trigger.name,
  };

  Future<SyncReport> apply(SyncManifest manifest) async {
    final restoring = _restoring;
    final sw = Stopwatch()..start();
    _mediaFailed = 0;
    _mediaDownloaded = 0;
    _logger.info(
      .syncStart,
      payload: {
        ..._backendPayload(),
        'direction': restoring ? 'restore' : 'pull',
      },
    );
    final diaryRepo = _diaryStore;
    final categoryRepo = _categoryStore;
    final placeRepo = _placeStore;
    final mediaInfoRepo = _mediaInfoStore;
    final localDiaries = {
      for (final d in await diaryRepo.getAllDiaries()) d.id: d,
    };
    final localPlaces = {
      for (final p in await placeRepo.getAllPlacesForSync()) p.id: p,
    };
    final localCategories = {
      for (final c in await categoryRepo.getAllCategoriesForSync()) c.id: c,
    };
    final localMediaInfos = {
      for (final a in await mediaInfoRepo.getAllMediaInfosForSync())
        a.fileName: a,
    };
    final tombstones = TombstoneBatch(await _tombstoneStore.getAll());

    final pending = _pending;
    {
      final newDiaries = <String>{};
      final updDiaries = <String>{};
      final newCategories = <String>{};
      final updCategories = <String>{};
      for (final entry in manifest.entries.entries) {
        if (entry.value.deleted) continue;
        final remoteMs = entry.value.timeMs;
        if (entry.key.startsWith(SyncKeys.diaryPrefix)) {
          final id = entry.key.substring(SyncKeys.diaryPrefix.length);
          final local = localDiaries[id];
          final tombMs = tombstones[entry.key]?.timeMs;
          if (local == null) {
            if (tombMs == null || remoteMs > tombMs) newDiaries.add(id);
          } else if (remoteMs > local.lastModified.millisecondsSinceEpoch) {
            updDiaries.add(id);
          }
        } else if (entry.key.startsWith(SyncKeys.categoryPrefix)) {
          final id = entry.key.substring(SyncKeys.categoryPrefix.length);
          final local = localCategories[id];
          final tombMs = tombstones[entry.key]?.timeMs;
          if (local == null) {
            if (tombMs == null || remoteMs > tombMs) newCategories.add(id);
          } else if (remoteMs > local.lastModified.millisecondsSinceEpoch) {
            updCategories.add(id);
          }
        }
      }
      pending.begin(
        newDiaryIds: newDiaries,
        updateDiaryIds: updDiaries,
        newCategoryIds: newCategories,
        updateCategoryIds: updCategories,
      );
    }

    final trackingId = backend.persistentBackendId;
    final fromSync = trackingId != null;

    int skipped = 0;
    int diaryChanged = 0;
    int categoryChanged = 0;
    int placeChanged = 0;
    int mediaInfoChanged = 0;
    int failed = 0;

    Future<void> pullOneEntry(MapEntry<String, ManifestEntry> entry) async {
      if (_cancellation.isRequested) return;
      final key = entry.key;
      final isTombstone = entry.value.deleted;
      try {
        if (key.startsWith(SyncKeys.diaryPrefix)) {
          final id = key.substring(SyncKeys.diaryPrefix.length);
          if (isTombstone) {
            if (restoring) return;
            final tombstoneMs = entry.value.timeMs;
            Diary? local = localDiaries[id];
            if (local != null) {
              local = await diaryRepo.getDiaryByBusinessId(id);
            }
            if (local != null &&
                local.lastModified.millisecondsSinceEpoch > tombstoneMs) {
              _logger.info(
                .diarySkip,
                reason: .localNewer,
                payload: {
                  'diaryId': id,
                  'localLastModified': local.lastModified.toIso8601String(),
                  'tombstoneMs': tombstoneMs,
                },
              );
              return;
            }
            if (local != null && _openDiaries.contains(id)) {
              _logger.info(
                .diarySkip,
                reason: .openDiary,
                payload: {'diaryId': id},
              );
              return;
            }
            if (local != null) {
              tombstones.add(
                await diaryRepo.tombstoneDiary(local, fromSync: fromSync),
              );
              await _deleteLocalMedia(local);
              diaryChanged++;
              _logger.info(.diaryTombstonePull, payload: {'diaryId': id});
            }
            if (trackingId != null) tombstones.markPushed(key, trackingId);
            return;
          }
          final remoteMs = entry.value.timeMs;
          final localMs =
              localDiaries[id]?.lastModified.millisecondsSinceEpoch ??
              (restoring ? null : tombstones[key]?.timeMs);
          if (localMs != null && remoteMs <= localMs) {
            skipped++;
            _logger.info(
              .diarySkip,
              reason: .upToDate,
              payload: {'diaryId': id},
            );
            final local = localDiaries[id];
            if (local != null) await _pullDiaryMedia(local);
            return;
          }
          final bytes = await backend.readObject(SyncKeys.diaryObjectPath(id));
          if (bytes == null) return;
          final decoded = await (await _cipher()).decode(bytes);
          if (decoded is! Map<String, dynamic>) return;
          await _adoptLegacyPosition(decoded);
          final diary = Diary.fromJson(decoded);
          if (diary.id != id) {
            failed++;
            _logger.error(
              .diaryDownload,
              payload: {'key': key, 'objectId': diary.id},
            );
            return;
          }
          await _pullDiaryMedia(diary);
          final oldDiary = await diaryRepo.getDiaryByBusinessId(id);
          final freshMs =
              oldDiary?.lastModified.millisecondsSinceEpoch ??
              (restoring
                  ? null
                  : (await _tombstoneStore.getByKey(key))?.timeMs);
          if (freshMs != null && remoteMs <= freshMs) {
            pending.completeDiary(id);
            _logger.info(
              .diarySkip,
              reason: .upToDate,
              payload: {'diaryId': id},
            );
            return;
          }
          await diaryRepo.insertADiary(
            restoring && oldDiary == null
                ? diary.copyWith(lastModified: DateTime.timestamp())
                : diary,
            fromSync: fromSync,
          );
          tombstones.remove(key);
          if (oldDiary != null) {
            await _mediaFiles.cleanUpReplaced(oldDiary, diary);
          }
          pending.completeDiary(id);
          diaryChanged++;
          _logger.info(
            .diaryDownload,
            payload: {
              'diaryId': id,
              if (diary.title.isNotEmpty) 'title': diary.title,
              'lastModified': diary.lastModified.toIso8601String(),
            },
          );
        } else if (key.startsWith(SyncKeys.categoryPrefix)) {
          final id = key.substring(SyncKeys.categoryPrefix.length);
          if (isTombstone) {
            if (restoring) return;
            final tombstoneMs = entry.value.timeMs;
            Category? local = localCategories[id];
            if (local != null) {
              local = await categoryRepo.getCategoryById(id);
            }
            if (local != null &&
                local.lastModified.millisecondsSinceEpoch > tombstoneMs) {
              _logger.info(
                .categorySkip,
                reason: .localNewer,
                payload: {'categoryId': id},
              );
              return;
            }
            if (local != null) {
              tombstones.add(
                await categoryRepo.tombstoneCategory(id, fromSync: fromSync),
              );
              categoryChanged++;
              _logger.info(.categoryTombstonePull, payload: {'categoryId': id});
            }
            if (trackingId != null) tombstones.markPushed(key, trackingId);
            return;
          }
          final remoteMs = entry.value.timeMs;
          final localMs =
              localCategories[id]?.lastModified.millisecondsSinceEpoch ??
              (restoring ? null : tombstones[key]?.timeMs);
          if (localMs != null && remoteMs <= localMs) {
            skipped++;
            _logger.info(
              .categorySkip,
              reason: .upToDate,
              payload: {'categoryId': id},
            );
            return;
          }
          final bytes = await backend.readObject(
            SyncKeys.categoryObjectPath(id),
          );
          if (bytes == null) return;
          final decoded = await (await _cipher()).decode(bytes);
          if (decoded is! Map<String, dynamic>) return;
          final freshLocal = await categoryRepo.getCategoryById(id);
          final freshMs =
              freshLocal?.lastModified.millisecondsSinceEpoch ??
              (restoring
                  ? null
                  : (await _tombstoneStore.getByKey(key))?.timeMs);
          if (freshMs != null && remoteMs <= freshMs) {
            pending.completeCategory(id);
            _logger.info(
              .categorySkip,
              reason: .upToDate,
              payload: {'categoryId': id},
            );
            return;
          }
          final category = Category.fromJson(decoded);
          if (category.id != id) {
            failed++;
            _logger.error(
              .categoryDownload,
              payload: {'key': key, 'objectId': category.id},
            );
            return;
          }
          await categoryRepo.insertACategory(
            restoring && freshLocal == null
                ? category.copyWith(lastModified: DateTime.timestamp())
                : category,
            fromSync: fromSync,
          );
          tombstones.remove(key);
          pending.completeCategory(id);
          categoryChanged++;
          _logger.info(.categoryDownload, payload: {'categoryId': id});
        } else if (key.startsWith(SyncKeys.placePrefix)) {
          final id = key.substring(SyncKeys.placePrefix.length);
          if (isTombstone) {
            if (restoring) return;
            final tombstoneMs = entry.value.timeMs;
            Place? local = localPlaces[id];
            if (local != null) {
              local = await placeRepo.getPlaceById(id);
            }
            if (local != null &&
                local.lastModified.millisecondsSinceEpoch > tombstoneMs) {
              _logger.info(
                .placeSkip,
                reason: .localNewer,
                payload: {'placeId': id},
              );
              return;
            }
            if (local != null) {
              tombstones.add(
                await placeRepo.tombstonePlace(id, fromSync: fromSync),
              );
              placeChanged++;
              _logger.info(.placeTombstonePull, payload: {'placeId': id});
            }
            if (trackingId != null) tombstones.markPushed(key, trackingId);
            return;
          }
          final remoteMs = entry.value.timeMs;
          final localMs =
              localPlaces[id]?.lastModified.millisecondsSinceEpoch ??
              (restoring ? null : tombstones[key]?.timeMs);
          if (localMs != null && remoteMs <= localMs) {
            skipped++;
            _logger.info(
              .placeSkip,
              reason: .upToDate,
              payload: {'placeId': id},
            );
            return;
          }
          final bytes = await backend.readObject(SyncKeys.placeObjectPath(id));
          if (bytes == null) return;
          final decoded = await (await _cipher()).decode(bytes);
          if (decoded is! Map<String, dynamic>) return;
          final freshLocal = await placeRepo.getPlaceById(id);
          final freshMs =
              freshLocal?.lastModified.millisecondsSinceEpoch ??
              (restoring
                  ? null
                  : (await _tombstoneStore.getByKey(key))?.timeMs);
          if (freshMs != null && remoteMs <= freshMs) {
            _logger.info(
              .placeSkip,
              reason: .upToDate,
              payload: {'placeId': id},
            );
            return;
          }
          final place = Place.fromJson(decoded);
          if (place.id != id) {
            failed++;
            _logger.error(
              .placeDownload,
              payload: {'key': key, 'objectId': place.id},
            );
            return;
          }
          await placeRepo.insertAPlace(
            restoring && freshLocal == null
                ? place.copyWith(lastModified: DateTime.timestamp())
                : place,
            fromSync: fromSync,
          );
          tombstones.remove(key);
          placeChanged++;
          _logger.info(
            .placeDownload,
            payload: {'placeId': id, 'placeName': place.name},
          );
        } else if (key.startsWith(SyncKeys.mediaInfoPrefix)) {
          final id = key.substring(SyncKeys.mediaInfoPrefix.length);
          if (isTombstone) {
            if (restoring) return;
            final tombstoneMs = entry.value.timeMs;
            MediaInfo? local = localMediaInfos[id];
            if (local != null) {
              local = await mediaInfoRepo.getMediaInfoByFileName(id);
            }
            if (local != null &&
                local.lastModified.millisecondsSinceEpoch > tombstoneMs) {
              _logger.info(
                .mediaInfoSkip,
                reason: .localNewer,
                payload: {'mediaFileName': id},
              );
              return;
            }
            if (local != null) {
              tombstones.add(
                await mediaInfoRepo.tombstoneMediaInfo(id, fromSync: fromSync),
              );
              mediaInfoChanged++;
              _logger.info(
                .mediaInfoTombstonePull,
                payload: {'mediaFileName': id},
              );
            }
            if (trackingId != null) tombstones.markPushed(key, trackingId);
            return;
          }
          final remoteMs = entry.value.timeMs;
          final localMs =
              localMediaInfos[id]?.lastModified.millisecondsSinceEpoch ??
              (restoring ? null : tombstones[key]?.timeMs);
          if (localMs != null && remoteMs <= localMs) {
            skipped++;
            _logger.info(
              .mediaInfoSkip,
              reason: .upToDate,
              payload: {'mediaFileName': id},
            );
            return;
          }
          final bytes = await backend.readObject(
            SyncKeys.mediaInfoObjectPath(id),
          );
          if (bytes == null) return;
          final decoded = await (await _cipher()).decode(bytes);
          if (decoded is! Map<String, dynamic>) return;
          final freshLocal = await mediaInfoRepo.getMediaInfoByFileName(id);
          final freshMs =
              freshLocal?.lastModified.millisecondsSinceEpoch ??
              (restoring
                  ? null
                  : (await _tombstoneStore.getByKey(key))?.timeMs);
          if (freshMs != null && remoteMs <= freshMs) {
            _logger.info(
              .mediaInfoSkip,
              reason: .upToDate,
              payload: {'mediaFileName': id},
            );
            return;
          }
          final mediaInfo = MediaInfo.fromJson(decoded);
          if (mediaInfo.fileName != id) {
            failed++;
            _logger.error(
              .mediaInfoDownload,
              payload: {'key': key, 'objectId': mediaInfo.fileName},
            );
            return;
          }
          await mediaInfoRepo.insertAMediaInfo(
            restoring && freshLocal == null
                ? mediaInfo.copyWith(lastModified: DateTime.timestamp())
                : mediaInfo,
            fromSync: fromSync,
          );
          tombstones.remove(key);
          mediaInfoChanged++;
          _logger.info(.mediaInfoDownload, payload: {'mediaFileName': id});
        }
      } catch (e) {
        failed++;
        _logger.error(
          switch (key) {
            final k when k.startsWith(SyncKeys.diaryPrefix) => .diaryDownload,
            final k when k.startsWith(SyncKeys.categoryPrefix) =>
              .categoryDownload,
            final k when k.startsWith(SyncKeys.placePrefix) => .placeDownload,
            final k when k.startsWith(SyncKeys.mediaInfoPrefix) =>
              .mediaInfoDownload,
            _ => .error,
          },
          payload: {'key': key, 'detail': e.toString()},
        );
      }
    }

    final entries = manifest.entries.entries.toList();
    final placeEntries = entries
        .where((e) => e.key.startsWith(SyncKeys.placePrefix))
        .toList();
    final otherEntries = entries
        .where((e) => !e.key.startsWith(SyncKeys.placePrefix))
        .toList();
    try {
      await runPooled(placeEntries, concurrency, pullOneEntry);
      await runPooled(otherEntries, concurrency, pullOneEntry);
    } finally {
      pending.clear();
    }

    await tombstones.flush(_tombstoneStore);

    sw.stop();
    final stopped = _cancellation.isRequested;
    _logger.info(
      .syncEnd,
      reason: stopped ? .stopped : null,
      payload: {
        ..._backendPayload(),
        'direction': 'pull',
        'diaryCount': diaryChanged,
        'categoryCount': categoryChanged,
        'placeCount': placeChanged,
        'mediaInfoCount': mediaInfoChanged,
        'mediaCount': _mediaDownloaded,
        'failed': failed,
        'mediaFailed': _mediaFailed,
        'cancelled': stopped,
        'elapsedMs': sw.elapsedMilliseconds,
      },
    );
    final totalFailed = failed + _mediaFailed;
    final warnings = [
      if (failed > 0) l10n.sync.warnFailedSkipped(count: failed),
      if (_mediaFailed > 0) l10n.sync.warnMediaFailed(count: _mediaFailed),
      if (stopped) l10n.sync.warnStopped,
    ].join('\n');
    return SyncReport(
      pulled: SyncCounts(
        diaries: diaryChanged,
        categories: categoryChanged,
        places: placeChanged,
        mediaInfos: mediaInfoChanged,
        mediaFiles: _mediaDownloaded,
      ),
      elapsed: sw.elapsed,
      warning: warnings.isEmpty ? null : warnings,
      failed: totalFailed,
      cancelled: stopped,
      skipped: skipped,
    );
  }

  Future<void> _adoptLegacyPosition(Map<String, dynamic> decoded) async {
    if (decoded['placeId'] is String) return;
    final position = decoded['position'];
    if (position is! Map) return;
    final lat = position['latitude'];
    final lon = position['longitude'];
    if (lat is! num || lon is! num) return;
    var name = (position['name'] is String ? position['name'] as String : '')
        .trim();
    if (name.isEmpty) {
      name = Place.coordinateName(lat.toDouble(), lon.toDouble());
    }
    var place =
        await _placeStore.getPlaceById(Place.idForName(name)) ??
        await _placeStore.getPlaceByName(name);
    if (place == null) {
      place = Place.forName(
        name,
        latitude: lat.toDouble(),
        longitude: lon.toDouble(),
      );
      await _placeStore.insertAPlace(place, fromSync: true);
    }
    decoded['placeId'] = place.id;
  }

  Future<void> _pullDiaryMedia(Diary diary) async {
    final entries = collectDiaryMediaEntries(diary);
    await Future.wait(
      entries.map((e) => _downloadMediaIfNeeded(e.$1, e.$2)),
      eagerError: false,
    );
  }

  Future<void> _downloadMediaIfNeeded(String type, String filename) async {
    if (await _mediaFiles.exists(type, filename)) return;
    await _mediaGate.withResource(() => _downloadMediaNow(type, filename));
  }

  Future<void> _downloadMediaNow(String type, String filename) async {
    try {
      if (await _mediaFiles.exists(type, filename)) {
        _logger.info(
          .mediaSkip,
          reason: .localExists,
          payload: {'type': type, 'filename': filename},
        );
        return;
      }

      final remotePath = SyncKeys.mediaObjectPath(type, filename);
      final localPath = _mediaFiles.realPath(type, filename);
      final int bytes;
      if (localPath != null && backend.supportsFileObjects) {
        final size = await _downloadMediaByFile(remotePath, localPath);
        if (size == null) {
          _logger.warn(
            .mediaSkip,
            reason: .remoteMissing,
            payload: {'type': type, 'filename': filename},
          );
          return;
        }
        bytes = size;
      } else {
        final encrypted = await backend.readObject(remotePath);
        if (encrypted == null || encrypted.isEmpty) {
          _logger.warn(
            .mediaSkip,
            reason: .remoteMissing,
            payload: {'type': type, 'filename': filename},
          );
          return;
        }
        final plain = await (await _cipher()).decryptBytes(encrypted);
        await _mediaFiles.write(type, filename, plain);
        bytes = plain.length;
      }
      _logger.info(
        .mediaDownload,
        payload: {'type': type, 'filename': filename, 'bytes': bytes},
      );
      _mediaDownloaded++;
      if (type == MediaType.image.value && localPath != null) {
        unawaited(FastImageDerivatives.warm(localPath));
      }
    } catch (e) {
      _mediaFailed++;
      _logger.error(
        .mediaDownload,
        payload: {'type': type, 'filename': filename, 'detail': e.toString()},
      );
    }
  }

  Future<int?> _downloadMediaByFile(String remotePath, String localPath) async {
    final temp = await _mediaTempFile('dec');
    try {
      if (!await backend.readObjectToFile(remotePath, temp.path)) return null;
      if (await temp.length() == 0) return null;
      await File(localPath).parent.create(recursive: true);
      final part = File('$localPath.part');
      try {
        await (await _cipher()).decryptFileTo(temp.path, part.path);
        await part.rename(localPath);
      } catch (_) {
        try {
          await part.delete();
        } catch (_) {}
        rethrow;
      }
      return await File(localPath).length();
    } finally {
      try {
        await temp.delete();
      } catch (_) {}
    }
  }

  Future<void> _deleteLocalMedia(Diary diary) async {
    final entries = collectDiaryMediaEntries(diary);
    await Future.wait(
      entries.map((e) async {
        try {
          await _mediaFiles.delete(e.$1, e.$2);
          _logger.info(.mediaDelete, payload: {'type': e.$1, 'filename': e.$2});
        } catch (_) {}
      }),
      eagerError: false,
    );
  }

  Future<File> _mediaTempFile(String tag) async {
    final dir = Directory(
      p.join(PlatformService.get().applicationCachePath, 'sync-media'),
    );
    await dir.create(recursive: true);
    return File(p.join(dir.path, '$tag-${uuidV7()}.tmp'));
  }
}

class TombstoneBatch {
  final Map<String, SyncTombstone> _rows;
  final Set<String> _dirty = {};
  final Set<String> _removed = {};

  TombstoneBatch(List<SyncTombstone> all)
    : _rows = {for (final t in all) t.key: t};

  SyncTombstone? operator [](String key) => _rows[key];

  List<SyncTombstone> snapshot() => _rows.values.toList();

  void add(SyncTombstone row) {
    _rows[row.key] = row;
    _removed.remove(row.key);
  }

  void markPushed(String key, String backendId) {
    final row = _rows[key];
    if (row == null || row.pushedBackends.contains(backendId)) return;
    _rows[key] = SyncTombstone(
      key: row.key,
      timeMs: row.timeMs,
      pushedBackends: [...row.pushedBackends, backendId],
    );
    _dirty.add(key);
  }

  void remove(String key) {
    if (_rows.remove(key) != null) {
      _dirty.remove(key);
      _removed.add(key);
    }
  }

  Future<void> flush(SyncTombstoneStore store) async {
    await store.putAll([for (final key in _dirty) _rows[key]!]);
    await store.deleteByKeys(_removed.toList());
    _dirty.clear();
    _removed.clear();
  }
}

Future<void> runPooled<T>(
  List<T> items,
  int concurrency,
  Future<void> Function(T) task,
) async {
  if (items.isEmpty) return;
  final pool = Pool(concurrency);
  try {
    await Future.wait(items.map((item) => pool.withResource(() => task(item))));
  } finally {
    await pool.close();
  }
}
