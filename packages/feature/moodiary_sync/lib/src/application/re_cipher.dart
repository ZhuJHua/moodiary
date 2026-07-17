import 'dart:typed_data';

import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/incremental_engine.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/remote_lease.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';

class ReCipherReport {
  final int diaryCount;
  final int categoryCount;
  final int mediaCount;
  final int failed;
  final Duration elapsed;

  const ReCipherReport({
    required this.diaryCount,
    required this.categoryCount,
    required this.mediaCount,
    required this.failed,
    required this.elapsed,
  });

  @override
  String toString() {
    final base =
        '日记 $diaryCount + 分类 $categoryCount + 媒体 $mediaCount '
        '（耗时 ${elapsed.inMilliseconds}ms）';
    return failed == 0 ? base : '$base\n$failed 个对象失败已跳过';
  }
}

/// 进度回调：当前已完成数 / 总数 / 当前 label。
typedef ReCipherProgress = void Function(int done, int total, String label);

/// 把远端 [backend] 上所有同步对象从 [from] 重新编码成 [to]（首次加密 / 换密钥 /
/// 解密回明文）。流程严格按「diary JSON → category JSON → media → manifest」顺序，
/// 失败逐项计数不中断；**manifest 最后写、写成功才算完成**，中途崩溃只是新旧编码混杂、
/// 下次 pull 仍能用各对象自身的 auth tag 解开未改写的部分。
/// 与 push/pull 共享 [IncrementalSyncEngine.runExclusive] 的互斥锁。
class CloudReCipher {
  final IRemoteSyncBackend backend;
  final SyncLogger _logger;

  /// manifest writeToken 的进程内序号，保证同微秒多次写也不撞。
  static int _seq = 0;

  CloudReCipher(this.backend, {SyncLogger? logger})
    : _logger = logger ?? SyncLogger.get();

  Map<String, Object?> _backendPayload() => {
    'backend': backend.displayName,
    'backendId': backend.persistentBackendId ?? 'transient',
  };

  /// 执行一次重新加/解密。远端无 manifest、或 from/to 都是明文 → 返回 `null`。
  Future<ReCipherReport?> run({
    required SyncCipher from,
    required SyncCipher to,
    ReCipherProgress? onProgress,
  }) {
    // 双重互斥：进程内锁 + 远端租约锁 —— 否则其它设备会读到新旧混杂的对象。
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
    _logger.info(SyncEventKind.syncStart, '开始重新加密', payload: {
      ..._backendPayload(),
      'direction': 're-cipher',
      'fromEncrypted': from.encrypted,
      'toEncrypted': to.encrypted,
    });

    // 读 manifest（用旧 cipher 解码）。密钥不匹配 → AES-GCM auth tag 失败抛 SyncException。
    final mfBytes = await backend.readObject(SyncKeys.manifestPath);
    if (mfBytes == null) {
      _logger.info(SyncEventKind.syncEnd, '远端为空，跳过重新加密', payload: {
        ..._backendPayload(),
        'direction': 're-cipher',
      });
      return null;
    }
    final mfDecoded = await from.decode(mfBytes);
    if (mfDecoded is! Map<String, dynamic>) {
      throw const SyncException('远端 manifest 格式异常，无法重新加密');
    }
    final manifest = SyncManifest.fromJson(mfDecoded);

    // 收集需改写的对象（跳过 tombstone：无 body）。媒体集合取 manifest 清单并集。
    final diaryIds = <String>[];
    final categoryIds = <String>[];
    for (final entry in manifest.entries.entries) {
      if (entry.value.deleted) continue;
      if (entry.key.startsWith(SyncKeys.diaryPrefix)) {
        diaryIds.add(entry.key.substring(SyncKeys.diaryPrefix.length));
      } else if (entry.key.startsWith(SyncKeys.categoryPrefix)) {
        categoryIds.add(entry.key.substring(SyncKeys.categoryPrefix.length));
      }
    }
    final mediaRefs = manifest.referencedMedia();

    int diaryCount = 0;
    int categoryCount = 0;
    int mediaCount = 0;
    int failed = 0;

    int done = 0;
    // 媒体引用在改写 diary 时还会补收（见 _collectMediaRefs），total 待后补媒体数。
    int total = diaryIds.length + categoryIds.length;
    void emitProgress(String label) =>
        onProgress?.call(done, total, label);
    emitProgress('准备');

    // JSON 对象改写无需理解内容：decode 的 Map 原样用新 cipher 编回。
    // [onDecoded] 在改写成功后拿到原始 JSON（日记循环用它补收媒体引用）。
    Future<bool?> reEncodeJson(
      String path, {
      void Function(Map<String, dynamic> decoded)? onDecoded,
    }) async {
      final bytes = await backend.readObject(path);
      // manifest 列出但远端缺失：跳过，不计失败。
      if (bytes == null) return null;
      final Object? decoded;
      try {
        decoded = await from.decode(bytes);
      } on SyncException {
        // 断点续跑：上次改写中断后重跑，对象可能已是目标编码 —— 能用新 cipher
        // 解开即跳过；解不开才是真错误（密钥不符 / 损坏），如实上抛计入失败。
        await to.decode(bytes);
        return null;
      }
      if (decoded is! Map<String, dynamic>) {
        _logger.warn(
          SyncEventKind.error,
          '远端对象解码非对象，跳过重新加密：$path',
          payload: {'path': path},
        );
        return false;
      }
      await backend.writeObject(path, await to.encode(decoded));
      onDecoded?.call(decoded);
      return true;
    }

    // 改写 diary JSON
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
          SyncEventKind.error,
          '重新加密日记失败：$id',
          payload: {'diaryId': id, 'detail': e.toString()},
        );
      }
      done++;
      emitProgress('日记 $id');
    }

    // 改写 category JSON
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
          SyncEventKind.error,
          '重新加密分类失败：$id',
          payload: {'categoryId': id, 'detail': e.toString()},
        );
      }
      done++;
      emitProgress('分类 $id');
    }

    // 改写媒体文件（manifest 并集 + diary JSON 补收的并集）
    total += mediaRefs.length;
    for (final ref in mediaRefs) {
      try {
        final path = SyncKeys.mediaObjectPathFromRef(ref);
        final bytes = await backend.readObject(path);
        if (bytes == null) {
          done++;
          continue;
        }
        final Uint8List plain;
        try {
          plain = await from.decryptBytes(bytes);
        } on SyncException {
          // 断点续跑：已是目标编码的媒体校验后跳过（同 reEncodeJson）。
          await to.decryptBytes(bytes);
          done++;
          continue;
        }
        final newBytes = await to.encryptBytes(plain);
        await backend.writeObject(path, newBytes);
        mediaCount++;
      } catch (e) {
        failed++;
        _logger.error(
          SyncEventKind.error,
          '重新加密媒体失败：$ref',
          payload: {'ref': ref, 'detail': e.toString()},
        );
      }
      done++;
      emitProgress('媒体 $ref');
    }

    // 改写 manifest。必须在所有对象改写后执行；密钥正确性由后续 pull 的 auth tag 兜底。
    emitProgress('写回 manifest');
    // token 含 deviceId + 微秒 + 进程内序号，避免同微秒并发写时回读校验误判通过。
    final token =
        'recipher:${MoodiaryKVs.syncDeviceId.get() ?? ''}:'
        '${DateTime.now().microsecondsSinceEpoch}:${_seq++}';
    final updated = manifest.copyForUpdate().withWriteToken(token);
    final newMfBytes = await to.encode(updated.toJson());
    await backend.writeObject(SyncKeys.manifestPath, newMfBytes);
    // 回读校验（用新 cipher 解）：token 不一致 = 另一台设备并发写了 manifest，
    // 中止以免新旧 cipher 的 manifest 互相覆盖。
    final verifyBytes = await backend.readObject(SyncKeys.manifestPath);
    final verifyDecoded =
        verifyBytes == null ? null : await to.decode(verifyBytes);
    final verifyToken = verifyDecoded is Map<String, dynamic>
        ? SyncManifest.fromJson(verifyDecoded).writeToken
        : null;
    if (verifyToken != token) {
      throw const SyncException('manifest 写入被其它设备并发覆盖，已中止重新加密');
    }

    sw.stop();
    _logger.info(SyncEventKind.syncEnd, '重新加密结束', payload: {
      ..._backendPayload(),
      'direction': 're-cipher',
      'diaryCount': diaryCount,
      'categoryCount': categoryCount,
      'mediaCount': mediaCount,
      'failed': failed,
      'elapsedMs': sw.elapsedMilliseconds,
    });

    return ReCipherReport(
      diaryCount: diaryCount,
      categoryCount: categoryCount,
      mediaCount: mediaCount,
      failed: failed,
      elapsed: sw.elapsed,
    );
  }

  /// 从 diary JSON 补收媒体引用（含视频缩略图）并入 [into]：覆盖「中断 push 已上传
  /// 但未进 manifest」的残留 —— 漏掉它们会保持旧密钥，之后 push stat 兜底又把它们
  /// 确认进新 manifest，从此永远解不开。
  static void _collectMediaRefs(Map<String, dynamic> json, Set<String> into) {
    void addAll(String type, Object? names) {
      if (names is! List) return;
      for (final n in names.whereType<String>()) {
        into.add('$type/$n');
        if (type == 'video') {
          final thumb = _thumbnailName(n);
          if (thumb != null) into.add('video/$thumb');
        }
      }
    }

    addAll('image', json['imageName']);
    addAll('audio', json['audioName']);
    addAll('video', json['videoName']);
  }

  /// 视频文件名 `video-<uuid>.mp4` → 缩略图名 `thumbnail-<uuid>.jpeg`。
  static String? _thumbnailName(String videoName) {
    if (!videoName.startsWith('video-')) return null;
    final dotIdx = videoName.lastIndexOf('.');
    if (dotIdx <= 6) return null;
    return 'thumbnail-${videoName.substring(6, dotIdx)}.jpeg';
  }
}
