import 'dart:io';
import 'dart:typed_data';

import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/incremental_engine.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/remote_lease.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:path/path.dart' as p;

class ReCipherReport {
  final int diaryCount;
  final int categoryCount;
  final int placeCount;
  final int mediaInfoCount;
  final int mediaCount;
  final int failed;
  final Duration elapsed;

  const ReCipherReport({
    required this.diaryCount,
    required this.categoryCount,
    this.placeCount = 0,
    this.mediaInfoCount = 0,
    required this.mediaCount,
    required this.failed,
    required this.elapsed,
  });

  @override
  String toString() {
    final base = l10n.sync.reCipherSummary(
      diary: diaryCount,
      category: categoryCount,
      mediaInfo: mediaInfoCount,
      media: mediaCount,
      ms: elapsed.inMilliseconds,
    );
    return failed == 0
        ? base
        : l10n.sync.reCipherFailedSuffix(base: base, failed: failed);
  }
}

typedef ReCipherProgress = void Function(int done, int total, String label);

class CloudReCipher {
  final RemoteObjectStore backend;
  final SyncLogger _logger;

  static int _seq = 0;

  CloudReCipher(this.backend, {SyncLogger? logger})
    : _logger = logger ?? getIt<SyncLogger>();

  Map<String, Object?> _backendPayload() => {
    'backend': backend.displayName,
    'backendId': backend.persistentBackendId ?? 'transient',
  };

  Future<ReCipherReport?> run({
    required SyncCipher from,
    required SyncCipher to,
    ReCipherProgress? onProgress,
  }) {
    return IncrementalSyncEngine.runExclusive(
      () => RemoteLease.protect(
        backend,
        () => _run(from: from, to: to, onProgress: onProgress),
        logger: _logger,
      ),
    );
  }

  Future<ReCipherReport?> _run({
    required SyncCipher from,
    required SyncCipher to,
    ReCipherProgress? onProgress,
  }) async {
    if (!from.encrypted && !to.encrypted) return null;

    final sw = Stopwatch()..start();
    _logger.info(
      .syncStart,
      payload: {
        ..._backendPayload(),
        'direction': 're-cipher',
        'fromEncrypted': from.encrypted,
        'toEncrypted': to.encrypted,
      },
    );

    final mfBytes = await backend.readObject(SyncKeys.manifestPath);
    if (mfBytes == null) {
      _logger.info(
        .syncEnd,
        reason: .remoteMissing,
        payload: {..._backendPayload(), 'direction': 're-cipher'},
      );
      return null;
    }
    final mfDecoded = await from.decode(mfBytes);
    if (mfDecoded is! Map<String, dynamic>) {
      throw SyncException(l10n.sync.errManifestReCipher);
    }
    final manifest = SyncManifest.fromJson(mfDecoded);

    final diaryIds = <String>[];
    final categoryIds = <String>[];
    final placeIds = <String>[];
    final mediaInfoIds = <String>[];
    for (final entry in manifest.entries.entries) {
      if (entry.value.deleted) continue;
      if (entry.key.startsWith(SyncKeys.diaryPrefix)) {
        diaryIds.add(entry.key.substring(SyncKeys.diaryPrefix.length));
      } else if (entry.key.startsWith(SyncKeys.categoryPrefix)) {
        categoryIds.add(entry.key.substring(SyncKeys.categoryPrefix.length));
      } else if (entry.key.startsWith(SyncKeys.placePrefix)) {
        placeIds.add(entry.key.substring(SyncKeys.placePrefix.length));
      } else if (entry.key.startsWith(SyncKeys.mediaInfoPrefix)) {
        mediaInfoIds.add(entry.key.substring(SyncKeys.mediaInfoPrefix.length));
      }
    }
    final mediaRefs = manifest.referencedMedia();

    int diaryCount = 0;
    int categoryCount = 0;
    int placeCount = 0;
    int mediaInfoCount = 0;
    int mediaCount = 0;
    int failed = 0;

    int done = 0;
    int total =
        diaryIds.length +
        categoryIds.length +
        placeIds.length +
        mediaInfoIds.length;
    void emitProgress(String label) => onProgress?.call(done, total, label);
    emitProgress(l10n.sync.stepPrepare);

    Future<bool?> reEncodeJson(
      String path, {
      void Function(Map<String, dynamic> decoded)? onDecoded,
    }) async {
      final bytes = await backend.readObject(path);
      if (bytes == null) return null;
      final Object? decoded;
      try {
        decoded = await from.decode(bytes);
      } on SyncException {
        await to.decode(bytes);
        return null;
      }
      if (decoded is! Map<String, dynamic>) {
        _logger.warn(.reCipher, reason: .decodeFailed, payload: {'path': path});
        return false;
      }
      await backend.writeObject(path, await to.encode(decoded));
      onDecoded?.call(decoded);
      return true;
    }

    for (final id in diaryIds) {
      try {
        final ok = await reEncodeJson(
          SyncKeys.diaryObjectPath(id),
          onDecoded: (json) => _collectMediaRefs(json, mediaRefs),
        );
        if (ok == true) {
          diaryCount++;
        } else if (ok == false) {
          failed++;
        }
      } catch (e) {
        failed++;
        _logger.error(
          .reCipher,
          payload: {'diaryId': id, 'detail': e.toString()},
        );
      }
      done++;
      emitProgress(l10n.sync.stepDiary(id: id));
    }

    for (final id in categoryIds) {
      try {
        final ok = await reEncodeJson(SyncKeys.categoryObjectPath(id));
        if (ok == true) {
          categoryCount++;
        } else if (ok == false) {
          failed++;
        }
      } catch (e) {
        failed++;
        _logger.error(
          .reCipher,
          payload: {'categoryId': id, 'detail': e.toString()},
        );
      }
      done++;
      emitProgress(l10n.sync.stepCategory(id: id));
    }

    for (final id in placeIds) {
      try {
        final ok = await reEncodeJson(SyncKeys.placeObjectPath(id));
        if (ok == true) {
          placeCount++;
        } else if (ok == false) {
          failed++;
        }
      } catch (e) {
        failed++;
        _logger.error(
          .reCipher,
          payload: {'placeId': id, 'detail': e.toString()},
        );
      }
      done++;
      emitProgress(l10n.sync.stepPlace(id: id));
    }

    for (final id in mediaInfoIds) {
      try {
        final ok = await reEncodeJson(SyncKeys.mediaInfoObjectPath(id));
        if (ok == true) {
          mediaInfoCount++;
        } else if (ok == false) {
          failed++;
        }
      } catch (e) {
        failed++;
        _logger.error(
          .reCipher,
          payload: {'mediaFileName': id, 'detail': e.toString()},
        );
      }
      done++;
      emitProgress(l10n.sync.stepMediaInfo(id: id));
    }

    total += mediaRefs.length;
    for (final ref in mediaRefs) {
      try {
        final path = SyncKeys.mediaObjectPathFromRef(ref);
        final rewritten = backend.supportsFileObjects
            ? await _reEncryptMediaByFile(path, from, to)
            : await _reEncryptMediaByBytes(path, from, to);
        if (!rewritten) {
          done++;
          continue;
        }
        mediaCount++;
      } catch (e) {
        failed++;
        _logger.error(.reCipher, payload: {'ref': ref, 'detail': e.toString()});
      }
      done++;
      emitProgress(l10n.sync.stepMedia(ref: ref));
    }

    emitProgress(l10n.sync.stepManifest);
    final token =
        'recipher:${MoodiaryKVs.syncDeviceId.get() ?? ''}:'
        '${DateTime.now().microsecondsSinceEpoch}:${_seq++}';
    final updated = manifest.copyForUpdate().withWriteToken(token);
    final newMfBytes = await to.encode(updated.toJson());
    await backend.writeObject(SyncKeys.manifestPath, newMfBytes);
    final verifyBytes = await backend.readObject(SyncKeys.manifestPath);
    final verifyDecoded = verifyBytes == null
        ? null
        : await to.decode(verifyBytes);
    final verifyToken = verifyDecoded is Map<String, dynamic>
        ? SyncManifest.fromJson(verifyDecoded).writeToken
        : null;
    if (verifyToken != token) {
      throw SyncException(l10n.sync.errManifestRace);
    }

    sw.stop();
    _logger.info(
      .syncEnd,
      payload: {
        ..._backendPayload(),
        'direction': 're-cipher',
        'diaryCount': diaryCount,
        'categoryCount': categoryCount,
        'placeCount': placeCount,
        'mediaCount': mediaCount,
        'failed': failed,
        'elapsedMs': sw.elapsedMilliseconds,
      },
    );

    return ReCipherReport(
      diaryCount: diaryCount,
      categoryCount: categoryCount,
      placeCount: placeCount,
      mediaInfoCount: mediaInfoCount,
      mediaCount: mediaCount,
      failed: failed,
      elapsed: sw.elapsed,
    );
  }

  Future<bool> _reEncryptMediaByFile(
    String path,
    SyncCipher from,
    SyncCipher to,
  ) async {
    final src = await _tempFile('rc-src');
    final plain = await _tempFile('rc-plain');
    final out = await _tempFile('rc-out');
    try {
      if (!await backend.readObjectToFile(path, src.path)) return false;
      try {
        await from.decryptFileTo(src.path, plain.path);
      } on SyncException {
        await to.decryptFileTo(src.path, plain.path);
        return false;
      }
      await to.encryptFileTo(plain.path, out.path);
      await backend.writeObjectFile(path, out.path);
      return true;
    } finally {
      for (final f in [src, plain, out]) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
  }

  Future<bool> _reEncryptMediaByBytes(
    String path,
    SyncCipher from,
    SyncCipher to,
  ) async {
    final bytes = await backend.readObject(path);
    if (bytes == null) return false;
    final Uint8List plain;
    try {
      plain = await from.decryptBytes(bytes);
    } on SyncException {
      await to.decryptBytes(bytes);
      return false;
    }
    await backend.writeObject(path, await to.encryptBytes(plain));
    return true;
  }

  Future<File> _tempFile(String tag) async {
    final dir = Directory(
      p.join(PlatformService.get().applicationCachePath, 'sync-media'),
    );
    await dir.create(recursive: true);
    return File(p.join(dir.path, '$tag-${uuidV7()}.tmp'));
  }

  static void _collectMediaRefs(Map<String, dynamic> json, Set<String> into) {
    void addAll(String type, Object? names) {
      if (names is! List) return;
      for (final n in names.whereType<String>()) {
        into.add('$type/$n');
        if (type == 'video') {
          final thumb = AppFiles.thumbnailNameOf(n);
          if (thumb != null) into.add('video/$thumb');
        }
      }
    }

    addAll('image', json['imageName']);
    addAll('audio', json['audioName']);
    addAll('video', json['videoName']);
  }
}
