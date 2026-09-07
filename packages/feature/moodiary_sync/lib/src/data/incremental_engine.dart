import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_sync/src/data/archive_apply.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/media_refs.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';
import 'package:moodiary_sync/src/data/remote_lease.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_cancellation.dart';
import 'package:moodiary_sync/src/data/sync_key_manager.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';
import 'package:moodiary_sync/src/data/sync_provider_scope.dart';
import 'package:moodiary_sync/src/data/sync_stores.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';

@internal
class IncrementalSyncEngine {
  final RemoteObjectStore backend;

  final int concurrency;

  final SyncLogger _logger;

  final Pool _mediaGate;

  final SyncDiaryStore _diaryStore;
  final SyncCategoryStore _categoryStore;
  final SyncPlaceStore _placeStore;
  final SyncMediaInfoStore _mediaInfoStore;
  final SyncTombstoneStore _tombstoneStore;
  final SyncMediaFiles _mediaFiles;

  final Future<SyncCipher> Function() _cipherProvider;

  SyncCipher? _cipherCache;

  Future<SyncCipher> _cipher() async =>
      _cipherCache ??= await _cipherProvider();

  static const int defaultConcurrency = 8;
  static const int _minConcurrency = 1;
  static const int _maxConcurrency = 32;

  static Future<IncrementalSyncEngine> forCloud(
    IRemoteSyncBackend backend, {
    SyncTrigger? trigger,
  }) async {
    if (!await backend.isReady()) throw backend.notReadyError;
    return IncrementalSyncEngine(backend, trigger: trigger);
  }

  factory IncrementalSyncEngine(
    RemoteObjectStore backend, {
    SyncLogger? logger,
    SyncDiaryStore? diaryStore,
    SyncCategoryStore? categoryStore,
    SyncPlaceStore? placeStore,
    SyncMediaInfoStore? mediaInfoStore,
    SyncTombstoneStore? tombstoneStore,
    SyncMediaFiles? mediaFiles,
    Future<SyncCipher> Function()? cipherProvider,
    int? concurrency,
    OpenDiaryRegistry? openDiaries,
    SyncCancellation? cancellation,
    SyncDirtyTracker? dirty,
    SyncTrigger? trigger,
  }) {
    final n = concurrency ?? _resolveConcurrency();
    return IncrementalSyncEngine._(
      _GatedBackend(backend, n),
      n,
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
      dirty ?? getIt<SyncDirtyTracker>(),
      trigger,
    );
  }

  IncrementalSyncEngine._(
    this.backend,
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
    this._dirty,
    this._trigger,
  ) : _mediaGate = Pool(concurrency);

  final OpenDiaryRegistry _openDiaries;
  final SyncCancellation _cancellation;
  final SyncDirtyTracker _dirty;

  final SyncTrigger? _trigger;

  int _mediaUploaded = 0;

  static int _resolveConcurrency() {
    final raw = MoodiaryKVs.syncConcurrency.get() ?? defaultConcurrency;
    return raw.clamp(_minConcurrency, _maxConcurrency).toInt();
  }

  static Future<T> runExclusive<T>(Future<T> Function() body) =>
      runSyncExclusive(body);

  bool _distrustRemoteMedia = false;

  Map<String, Object?> _backendPayload() => {
    'backend': backend.displayName,
    'backendId': backend.persistentBackendId ?? 'transient',
    if (_trigger != null) 'trigger': _trigger.name,
  };

  Future<T> _exclusive<T>(Future<T> Function() body) {
    return runSyncExclusive(
      () => RemoteLease.protect(backend, () async {
        try {
          return await body();
        } catch (e) {
          _logger.error(
            .syncEnd,
            reason: .aborted,
            payload: {..._backendPayload(), 'error': e.toString()},
          );
          rethrow;
        }
      }, logger: _logger),
    );
  }

  Future<SyncReport> pull({bool markSynced = true}) async {
    final report = await _exclusive(_pull);
    if (markSynced && report.failed == 0 && !report.cancelled) {
      _markSynced();
    }
    return report;
  }

  Future<SyncReport> _pull() async => (await _pullCore()).$1;

  Future<(SyncReport, SyncManifest?)> _pullCore() async {
    await _uploadPendingKeyfile();
    final sw = Stopwatch()..start();
    final manifest = await _readManifest();
    if (manifest == null) {
      sw.stop();
      _logger.info(
        .syncStart,
        payload: {..._backendPayload(), 'direction': 'pull'},
      );
      _logger.warn(.manifestRead, reason: .remoteMissing);
      _logger.info(
        .syncEnd,
        payload: {
          ..._backendPayload(),
          'direction': 'pull',
          'diaryCount': 0,
          'categoryCount': 0,
          'failed': 0,
          'elapsedMs': sw.elapsedMilliseconds,
        },
      );
      return (
        SyncReport(elapsed: sw.elapsed, warning: l10n.sync.warnRemoteEmpty),
        null,
      );
    }
    _logger.info(.manifestRead, payload: {'entries': manifest.entries.length});

    final report = await ArchiveApplier(
      backend,
      policy: const SyncPullPolicy(),
      logger: _logger,
      diaryStore: _diaryStore,
      categoryStore: _categoryStore,
      placeStore: _placeStore,
      mediaInfoStore: _mediaInfoStore,
      tombstoneStore: _tombstoneStore,
      mediaFiles: _mediaFiles,
      cipherProvider: _cipher,
      concurrency: concurrency,
      openDiaries: _openDiaries,
      cancellation: _cancellation,
      trigger: _trigger,
    ).apply(manifest);
    return (report, manifest);
  }

  Future<SyncReport> push() async {
    final report = await _exclusive(_push);
    if (report.failed == 0 && !report.cancelled) _markSynced();
    return report;
  }

  Future<SyncReport> sync() async {
    final report = await _exclusive(() async {
      final sw = Stopwatch()..start();
      final (pulled, manifest) = await _pullCore();
      if (pulled.cancelled) {
        sw.stop();
        return SyncReport(
          pulled: pulled.pulled,
          elapsed: sw.elapsed,
          warning: pulled.warning,
          failed: pulled.failed,
          cancelled: true,
        );
      }
      final reuse =
          manifest != null &&
          !pulled.pulled.hasEntryChanges &&
          pulled.failed == 0;
      final pushed = await _push(preloaded: reuse ? manifest : null);
      sw.stop();
      final warnings = [
        pulled.warning,
        pushed.warning,
      ].whereType<String>().join('\n');
      return SyncReport(
        pushed: pushed.pushed,
        pulled: pulled.pulled,
        elapsed: sw.elapsed,
        warning: warnings.isEmpty ? null : warnings,
        failed: pulled.failed + pushed.failed,
        cancelled: pushed.cancelled,
        skippedOpen: pushed.skippedOpen,
      );
    });
    if (report.failed == 0 && !report.cancelled) _markSynced();
    return report;
  }

  static void _markSynced() =>
      MoodiaryKVs.lastSyncTime.set(DateTime.now().millisecondsSinceEpoch);

  static int _writeSeq = 0;

  String _newWriteToken() {
    final id = MoodiaryKVs.syncDeviceId.get() ?? '';
    return '$id:${DateTime.now().microsecondsSinceEpoch}:${_writeSeq++}';
  }

  Future<SyncReport> _push({SyncManifest? preloaded}) async {
    await _uploadPendingKeyfile();
    _distrustRemoteMedia = SyncKeyManager.hasForceMediaReupload(
      backend.persistentBackendId,
    );
    final sw = Stopwatch()..start();
    _mediaUploaded = 0;
    _logger.info(
      .syncStart,
      payload: {..._backendPayload(), 'direction': 'push'},
    );
    SyncManifest? read = preloaded;
    var virginRemote = false;
    if (read == null) {
      read = await _readManifest();
      virginRemote = read == null;
    }
    final manifest = read ?? .empty();
    if (virginRemote && (await _cipher()).encrypted) {
      await _ensureKeyfileOnVirginRemote();
    }
    _logger.info(.manifestRead, payload: {'entries': manifest.entries.length});
    final updated = manifest.copyForUpdate();

    final remoteMedia = manifest.referencedMedia();

    bool stillReferenced(String ref) =>
        updated.entries.values.any((e) => !e.deleted && e.media.contains(ref));

    final openSnapshot = _openDiaries.snapshot();
    final allDiaries = await _diaryStore.getAllDiaries();
    final diaries = allDiaries
        .where((d) => !openSnapshot.contains(d.id))
        .toList();
    final skippedOpen = allDiaries.length - diaries.length;
    final categories = await _categoryStore.getAllCategoriesForSync();
    final places = await _placeStore.getAllPlacesForSync();
    final mediaInfoRows = await _mediaInfoStore.getAllMediaInfosForSync();

    int diaryChanged = 0;
    int categoryChanged = 0;
    int placeChanged = 0;
    int mediaInfoChanged = 0;
    int failed = 0;

    final trackingId = backend.persistentBackendId;
    final configuredBackends = await configuredCloudBackendIds();
    final tombstones = TombstoneBatch(await _tombstoneStore.getAll());
    final coveredTombstoneKeys = <String>[];

    final pushedDiaryIds = <String>[];

    final deferredObjectDeletes = <String>[];
    final deferredMediaDeletes = <String>{};

    void scheduleCleanup(String key) {
      if (trackingId == null) {
        coveredTombstoneKeys.add(key);
        return;
      }
      final pushed = tombstones[key]?.pushedBackends ?? const <String>[];
      if (pushed.toSet().containsAll(configuredBackends)) {
        coveredTombstoneKeys.add(key);
      }
    }

    Future<void> pushOneDiary(Diary diary) async {
      if (_cancellation.isRequested) return;
      final key = SyncKeys.diary(diary.id);
      final remoteEntry = manifest.entries[key];

      final remoteMs = remoteEntry?.timeMs;
      if (remoteMs != null &&
          diary.lastModified.millisecondsSinceEpoch <= remoteMs) {
        _logger.info(
          .diarySkip,
          reason: .upToDate,
          payload: {'diaryId': diary.id},
        );
        pushedDiaryIds.add(diary.id);
        return;
      }

      try {
        final confirmedRefs = await _pushDiaryMedia(diary, remoteMedia);
        final bytes = await (await _cipher()).encode(diary.toJson());
        await backend.writeObject(SyncKeys.diaryObjectPath(diary.id), bytes);
        updated.entries[key] = ManifestEntry(
          timeMs: diary.lastModified.millisecondsSinceEpoch,
          media: confirmedRefs,
        );
        remoteMedia.addAll(confirmedRefs);
        final newRefs = _mediaRefs(diary).toSet();
        final staleRefs =
            (remoteEntry?.deleted ?? true
                    ? const <String>[]
                    : remoteEntry!.media)
                .where((r) => !newRefs.contains(r) && !stillReferenced(r))
                .toList();
        deferredMediaDeletes.addAll(staleRefs);
        remoteMedia.removeAll(staleRefs);
        pushedDiaryIds.add(diary.id);
        diaryChanged++;
        _logger.info(
          .diaryUpload,
          payload: {
            'diaryId': diary.id,
            if (diary.title.isNotEmpty) 'title': diary.title,
            'bytes': bytes.length,
            'lastModified': diary.lastModified.toIso8601String(),
          },
        );
      } catch (e) {
        failed++;
        _logger.error(
          .diaryUpload,
          payload: {
            'diaryId': diary.id,
            if (diary.title.isNotEmpty) 'title': diary.title,
            'detail': e.toString(),
          },
        );
      }
    }

    await runPooled(diaries, concurrency, pushOneDiary);

    Future<void> pushOneCategory(Category category) async {
      if (_cancellation.isRequested) return;
      final key = SyncKeys.category(category.id);
      final remoteEntry = manifest.entries[key];
      final remoteMs = remoteEntry?.timeMs;
      if (remoteMs != null &&
          category.lastModified.millisecondsSinceEpoch <= remoteMs) {
        _logger.info(
          .categorySkip,
          reason: .upToDate,
          payload: {'categoryId': category.id},
        );
        return;
      }
      try {
        final bytes = await (await _cipher()).encode(category.toJson());
        await backend.writeObject(
          SyncKeys.categoryObjectPath(category.id),
          bytes,
        );
        updated.entries[key] = ManifestEntry(
          timeMs: category.lastModified.millisecondsSinceEpoch,
        );
        categoryChanged++;
        _logger.info(
          .categoryUpload,
          payload: {'categoryId': category.id, 'bytes': bytes.length},
        );
      } catch (e) {
        failed++;
        _logger.error(
          .categoryUpload,
          payload: {'categoryId': category.id, 'detail': e.toString()},
        );
      }
    }

    await runPooled(categories, concurrency, pushOneCategory);

    Future<void> pushOnePlace(Place place) async {
      if (_cancellation.isRequested) return;
      final key = SyncKeys.place(place.id);
      final remoteEntry = manifest.entries[key];
      final remoteMs = remoteEntry?.timeMs;
      if (remoteMs != null &&
          place.lastModified.millisecondsSinceEpoch <= remoteMs) {
        _logger.info(
          .placeSkip,
          reason: .upToDate,
          payload: {'placeId': place.id, 'placeName': place.name},
        );
        return;
      }
      try {
        final bytes = await (await _cipher()).encode(place.toJson());
        await backend.writeObject(SyncKeys.placeObjectPath(place.id), bytes);
        updated.entries[key] = ManifestEntry(
          timeMs: place.lastModified.millisecondsSinceEpoch,
        );
        placeChanged++;
        _logger.info(
          .placeUpload,
          payload: {
            'placeId': place.id,
            'placeName': place.name,
            'bytes': bytes.length,
          },
        );
      } catch (e) {
        failed++;
        _logger.error(
          .placeUpload,
          payload: {'placeId': place.id, 'detail': e.toString()},
        );
      }
    }

    await runPooled(places, concurrency, pushOnePlace);

    Future<void> pushOneMediaInfo(MediaInfo mediaInfo) async {
      if (_cancellation.isRequested) return;
      final key = SyncKeys.mediaInfo(mediaInfo.fileName);
      final remoteEntry = manifest.entries[key];
      final remoteMs = remoteEntry?.timeMs;
      if (remoteMs != null &&
          mediaInfo.lastModified.millisecondsSinceEpoch <= remoteMs) {
        _logger.info(
          .mediaInfoSkip,
          reason: .upToDate,
          payload: {'mediaFileName': mediaInfo.fileName},
        );
        return;
      }
      try {
        final bytes = await (await _cipher()).encode(mediaInfo.toJson());
        await backend.writeObject(
          SyncKeys.mediaInfoObjectPath(mediaInfo.fileName),
          bytes,
        );
        updated.entries[key] = ManifestEntry(
          timeMs: mediaInfo.lastModified.millisecondsSinceEpoch,
        );
        mediaInfoChanged++;
        _logger.info(
          .mediaInfoUpload,
          payload: {'mediaFileName': mediaInfo.fileName, 'bytes': bytes.length},
        );
      } catch (e) {
        failed++;
        _logger.error(
          .mediaInfoUpload,
          payload: {
            'mediaFileName': mediaInfo.fileName,
            'detail': e.toString(),
          },
        );
      }
    }

    await runPooled(mediaInfoRows, concurrency, pushOneMediaInfo);

    void pushOneTombstone(SyncTombstone t) {
      final key = t.key;
      final remoteEntry = manifest.entries[key];
      final kind = t.kind;
      if (kind == null) {
        _logger.warn(.error, reason: .unknownTombstone, payload: {'key': key});
        return;
      }
      final (skipKind, pushKind, idKey) = switch (kind) {
        .diary => (
          SyncEventKind.diarySkip,
          SyncEventKind.diaryTombstonePush,
          'diaryId',
        ),
        .category => (
          SyncEventKind.categorySkip,
          SyncEventKind.categoryTombstonePush,
          'categoryId',
        ),
        .place => (
          SyncEventKind.placeSkip,
          SyncEventKind.placeTombstonePush,
          'placeId',
        ),
        .mediaInfo => (
          SyncEventKind.mediaInfoSkip,
          SyncEventKind.mediaInfoTombstonePush,
          'mediaFileName',
        ),
      };
      if (remoteEntry == null || remoteEntry.deleted) {
        if (trackingId != null) tombstones.markPushed(key, trackingId);
        scheduleCleanup(key);
        return;
      }
      if (remoteEntry.timeMs >= t.timeMs) {
        _logger.info(
          skipKind,
          reason: .remoteNewer,
          payload: {
            idKey: t.entityId,
            'remoteMs': remoteEntry.timeMs,
            'localDeleteMs': t.timeMs,
          },
        );
        return;
      }
      updated.entries[key] = ManifestEntry(timeMs: t.timeMs, deleted: true);
      switch (kind) {
        case .diary:
          deferredObjectDeletes.add(SyncKeys.diaryObjectPath(t.entityId));
          final staleRefs = remoteEntry.media
              .where((r) => !stillReferenced(r))
              .toList();
          deferredMediaDeletes.addAll(staleRefs);
          remoteMedia.removeAll(staleRefs);
          diaryChanged++;
        case .category:
          deferredObjectDeletes.add(SyncKeys.categoryObjectPath(t.entityId));
          categoryChanged++;
        case .place:
          deferredObjectDeletes.add(SyncKeys.placeObjectPath(t.entityId));
          placeChanged++;
        case .mediaInfo:
          deferredObjectDeletes.add(SyncKeys.mediaInfoObjectPath(t.entityId));
          mediaInfoChanged++;
      }
      if (trackingId != null) tombstones.markPushed(key, trackingId);
      _logger.info(
        pushKind,
        payload: {idKey: t.entityId, 'tombstoneMs': t.timeMs},
      );
      scheduleCleanup(key);
    }

    for (final t in tombstones.snapshot()) {
      if (_cancellation.isRequested) break;
      pushOneTombstone(t);
    }

    if (diaryChanged > 0 ||
        categoryChanged > 0 ||
        placeChanged > 0 ||
        mediaInfoChanged > 0) {
      final token = _newWriteToken();
      final manifestBytes = await (await _cipher()).encode(
        updated.withWriteToken(token).toJson(),
      );
      await backend.writeObject(SyncKeys.manifestPath, manifestBytes);
      final readback = await _readManifest();
      if (readback?.writeToken != token) {
        throw SyncException(l10n.sync.errManifestRacePush, kind: .manifestRace);
      }
      _logger.info(
        .manifestWrite,
        payload: {
          'entries': updated.entries.length,
          'bytes': manifestBytes.length,
        },
      );
    }

    await _deleteRemoteObjects(deferredObjectDeletes);
    final mediaToDelete = deferredMediaDeletes
        .where((r) => !stillReferenced(r))
        .toList();
    await _deleteRemoteMediaRefs(mediaToDelete);
    for (final key in coveredTombstoneKeys) {
      tombstones.remove(key);
    }
    await tombstones.flush(_tombstoneStore);
    for (final id in pushedDiaryIds) {
      _dirty.clearDirty(id);
    }

    sw.stop();
    final stopped = _cancellation.isRequested;
    if (_distrustRemoteMedia && failed == 0 && !stopped) {
      SyncKeyManager.clearForceMediaReupload(backend.persistentBackendId);
      _distrustRemoteMedia = false;
    }
    _logger.info(
      .syncEnd,
      reason: stopped ? .stopped : null,
      payload: {
        ..._backendPayload(),
        'direction': 'push',
        'diaryCount': diaryChanged,
        'categoryCount': categoryChanged,
        'placeCount': placeChanged,
        'mediaInfoCount': mediaInfoChanged,
        'mediaCount': _mediaUploaded,
        'failed': failed,
        'cancelled': stopped,
        'skippedOpen': skippedOpen,
        'elapsedMs': sw.elapsedMilliseconds,
      },
    );
    final warnings = [
      if (failed > 0) l10n.sync.warnFailedSkipped(count: failed),
      if (stopped) l10n.sync.warnStopped,
    ].join('\n');
    return SyncReport(
      pushed: SyncCounts(
        diaries: diaryChanged,
        categories: categoryChanged,
        places: placeChanged,
        mediaInfos: mediaInfoChanged,
        mediaFiles: _mediaUploaded,
      ),
      elapsed: sw.elapsed,
      warning: warnings.isEmpty ? null : warnings,
      failed: failed,
      cancelled: stopped,
      skippedOpen: skippedOpen,
    );
  }

  Future<void> _ensureKeyfileOnVirginRemote() async {
    switch (await SyncKeyManager.checkRemoteKeyfile(backend)) {
      case .conflict:
        SyncKeyManager.markKeyConflict(backend.persistentBackendId);
        throw SyncKeyConflictException(l10n.sync.errKeyConflict);
      case .unknown:
        throw SyncException(l10n.sync.errKeyfileOwnerUnknown);
      case .safe:
        break;
    }
    final keyfile = SyncKeyManager.cachedKeyfile();
    if (keyfile == null) {
      throw SyncException(l10n.sync.errKeyfileNoLocalCache);
    }
    await SyncKeyManager.writeRemoteKeyfile(backend, keyfile);
    final backendId = backend.persistentBackendId;
    if (backendId != null) {
      await SyncKeyManager.clearPendingUpload(backendId);
    }
    _logger.info(.keyfileUpload, payload: _backendPayload());
  }

  Future<void> _uploadPendingKeyfile() async {
    try {
      await SyncKeyManager.uploadPendingKeyfile(backend);
    } on SyncKeyConflictException catch (e) {
      _logger.error(
        .keyConflict,
        payload: {..._backendPayload(), 'detail': e.message},
      );
      rethrow;
    } catch (e) {
      _logger.warn(
        .keyfileUpload,
        payload: {..._backendPayload(), 'detail': e.toString()},
      );
    }
  }

  Future<SyncManifest?> _readManifest() async {
    final bytes = await backend.readObject(SyncKeys.manifestPath);
    if (bytes == null) return null;
    final decoded = await (await _cipher()).decode(bytes);
    if (decoded is! Map<String, dynamic>) {
      throw SyncException(l10n.sync.errManifestCorrupt, kind: .manifestCorrupt);
    }
    return .fromJson(decoded);
  }

  List<String> _mediaRefs(Diary diary) => [
    for (final e in collectDiaryMediaEntries(diary))
      SyncKeys.mediaRef(e.$1, e.$2),
  ];

  Future<List<String>> _pushDiaryMedia(
    Diary diary,
    Set<String> remoteMedia,
  ) async {
    final entries = collectDiaryMediaEntries(diary);
    final results = await Future.wait(
      entries.map((e) => _uploadMediaIfNeeded(e.$1, e.$2, remoteMedia)),
      eagerError: false,
    );
    if (results.any((r) => r == false)) {
      throw SyncException(l10n.sync.errMediaUpload);
    }
    return [
      for (var i = 0; i < entries.length; i++)
        if (results[i] == true) SyncKeys.mediaRef(entries[i].$1, entries[i].$2),
    ];
  }

  Future<bool?> _uploadMediaIfNeeded(
    String type,
    String filename,
    Set<String> remoteMedia,
  ) {
    if (remoteMedia.contains(SyncKeys.mediaRef(type, filename))) {
      return .value(true);
    }
    return _mediaGate.withResource(
      () => _uploadMediaNow(type, filename, remoteMedia),
    );
  }

  Future<bool?> _uploadMediaNow(
    String type,
    String filename,
    Set<String> remoteMedia,
  ) async {
    try {
      if (!await _mediaFiles.exists(type, filename)) {
        _logger.warn(
          .mediaSkip,
          reason: .localMissing,
          payload: {'type': type, 'filename': filename},
        );
        return null;
      }

      final remotePath = SyncKeys.mediaObjectPath(type, filename);
      // stat 失败照常上传：无 ListBucket 权限的 S3 回 403、反代回 405/429，都不是 404
      String? remoteModified;
      try {
        remoteModified = _distrustRemoteMedia
            ? null
            : await backend.statObject(remotePath);
      } catch (e) {
        _logger.warn(
          .mediaSkip,
          reason: .probeFailed,
          payload: {'type': type, 'filename': filename, 'detail': e.toString()},
        );
      }
      if (remoteModified != null) {
        _logger.info(
          .mediaSkip,
          reason: .remoteExists,
          payload: {'type': type, 'filename': filename},
        );
        remoteMedia.add(SyncKeys.mediaRef(type, filename));
        return true;
      }

      final localPath = _mediaFiles.realPath(type, filename);
      final int bytes;
      if (localPath != null && backend.supportsFileObjects) {
        bytes = await _uploadMediaByFile(localPath, remotePath);
      } else {
        final plain = await _mediaFiles.read(type, filename);
        final encrypted = await (await _cipher()).encryptBytes(plain);
        await backend.writeObject(remotePath, encrypted);
        bytes = encrypted.length;
      }
      _logger.info(
        .mediaUpload,
        payload: {'type': type, 'filename': filename, 'bytes': bytes},
      );
      _mediaUploaded++;
      remoteMedia.add(SyncKeys.mediaRef(type, filename));
      return true;
    } catch (e) {
      _logger.error(
        .mediaUpload,
        payload: {'type': type, 'filename': filename, 'detail': e.toString()},
      );
      return false;
    }
  }

  Future<void> _deleteRemoteObjects(Iterable<String> paths) async {
    await Future.wait(
      paths.map((path) async {
        try {
          await backend.deleteObject(path);
        } catch (_) {}
      }),
      eagerError: false,
    );
  }

  Future<void> _deleteRemoteMediaRefs(Iterable<String> refs) async {
    await Future.wait(
      refs.map((ref) async {
        try {
          await backend.deleteObject(SyncKeys.mediaObjectPathFromRef(ref));
          _logger.info(.mediaDelete, payload: {'ref': ref});
        } catch (_) {}
      }),
      eagerError: false,
    );
  }

  Future<int> _uploadMediaByFile(String localPath, String remotePath) async {
    final temp = await _mediaTempFile('enc');
    try {
      await (await _cipher()).encryptFileTo(localPath, temp.path);
      await backend.writeObjectFile(remotePath, temp.path);
      return await temp.length();
    } finally {
      try {
        await temp.delete();
      } catch (_) {}
    }
  }

  Future<File> _mediaTempFile(String tag) async {
    final dir = Directory(
      p.join(PlatformService.get().applicationCachePath, 'sync-media'),
    );
    await dir.create(recursive: true);
    return File(p.join(dir.path, '$tag-${uuidV7()}.tmp'));
  }
}

class _GatedBackend implements RemoteObjectStore {
  final RemoteObjectStore _inner;
  final Pool _gate;

  _GatedBackend(this._inner, int concurrency) : _gate = Pool(concurrency);

  @override
  Future<Uint8List?> readObject(String key) =>
      _gate.withResource(() => _inner.readObject(key));

  @override
  Future<void> writeObject(String key, Uint8List bytes) =>
      _gate.withResource(() => _inner.writeObject(key, bytes));

  @override
  bool get supportsFileObjects => _inner.supportsFileObjects;

  @override
  Future<bool> readObjectToFile(String key, String filePath) =>
      _gate.withResource(() => _inner.readObjectToFile(key, filePath));

  @override
  Future<void> writeObjectFile(String key, String filePath) =>
      _gate.withResource(() => _inner.writeObjectFile(key, filePath));

  @override
  Future<bool> tryCreateExclusive(String key, Uint8List bytes) =>
      _gate.withResource(() => _inner.tryCreateExclusive(key, bytes));

  @override
  Future<void> deleteObject(String key) =>
      _gate.withResource(() => _inner.deleteObject(key));

  @override
  Future<String?> statObject(String key) =>
      _gate.withResource(() => _inner.statObject(key));

  @override
  String get displayName => _inner.displayName;

  @override
  String? get persistentBackendId => _inner.persistentBackendId;
}

Future<void> purgeSyncMediaTemp() async {
  final dir = Directory(
    p.join(PlatformService.get().applicationCachePath, 'sync-media'),
  );
  try {
    if (await dir.exists()) await dir.delete(recursive: true);
  } catch (_) {}
}
