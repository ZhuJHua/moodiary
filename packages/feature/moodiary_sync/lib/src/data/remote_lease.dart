import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

class LeasePayload {
  final String owner;
  final DateTime acquiredAt;
  final Duration ttl;

  const LeasePayload({
    required this.owner,
    required this.acquiredAt,
    required this.ttl,
  });

  static LeasePayload? fromBytes(Uint8List bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) return null;
      final owner = decoded['owner'];
      final acquiredAt = DateTime.tryParse(
        decoded['acquiredAt'] as String? ?? '',
      );
      final ttlSeconds = decoded['ttlSeconds'];
      if (owner is! String ||
          owner.isEmpty ||
          acquiredAt == null ||
          ttlSeconds is! int ||
          ttlSeconds <= 0) {
        return null;
      }
      return LeasePayload(
        owner: owner,
        acquiredAt: acquiredAt,
        ttl: Duration(seconds: ttlSeconds),
      );
    } catch (_) {
      return null;
    }
  }

  Uint8List toBytes() => .fromList(
    utf8.encode(
      jsonEncode({
        'owner': owner,
        'acquiredAt': acquiredAt.toUtc().toIso8601String(),
        'ttlSeconds': ttl.inSeconds,
      }),
    ),
  );

  bool isExpired(DateTime now, {Duration skew = RemoteLease.clockSkewMargin}) =>
      now.isAfter(acquiredAt.add(ttl).add(skew));
}

class RemoteLease {
  RemoteLease._();

  static const Duration ttl = Duration(minutes: 5);

  static const Duration clockSkewMargin = Duration(minutes: 1);

  static const Duration renewInterval = Duration(seconds: 100);

  static const int _maxAttempts = 4;
  static const Duration _retryDelay = Duration(seconds: 3);

  static final Random _random = Random();

  static final Map<String, bool> _casVerified = {};

  static void resetCasProbeCache() => _casVerified.clear();

  @visibleForTesting
  static Duration? readbackSettleDelay;

  static Future<String> _ensureDeviceId() async {
    final existing = MoodiaryKVs.syncDeviceId.get();
    if (existing != null && existing.isNotEmpty) return existing;
    final id = uuidV4();
    MoodiaryKVs.syncDeviceId.set(id);
    return id;
  }

  static Future<LeasePayload?> _read(RemoteObjectStore backend) async {
    final bytes = await backend.readObject(SyncKeys.lockPath);
    if (bytes == null) return null;
    return .fromBytes(bytes);
  }

  static Future<T> protect<T>(
    RemoteObjectStore backend,
    Future<T> Function() body, {
    SyncLogger? logger,
  }) async {
    final log = logger ?? getIt<SyncLogger>();
    final owner = await _ensureDeviceId();
    await _acquire(backend, owner, log);

    Timer? renewTimer;
    Future<void>? pendingRenew;
    var held = true;
    try {
      renewTimer = .periodic(renewInterval, (_) {
        pendingRenew = _renew(backend, owner, log).then((kept) {
          if (!kept) {
            held = false;
            renewTimer?.cancel();
          }
        });
      });
      return await body();
    } finally {
      renewTimer?.cancel();
      await pendingRenew;
      if (held) await _release(backend, owner, log);
    }
  }

  static Future<bool> _renew(
    RemoteObjectStore backend,
    String owner,
    SyncLogger log,
  ) async {
    try {
      final current = await _read(backend);
      if (current != null && current.owner != owner) {
        log.warn(
          .lockRelease,
          reason: .renewFailed,
          payload: {'holder': current.owner},
        );
        return false;
      }
      await backend.writeObject(
        SyncKeys.lockPath,
        LeasePayload(
          owner: owner,
          acquiredAt: DateTime.timestamp(),
          ttl: ttl,
        ).toBytes(),
      );
      return true;
    } catch (e) {
      log.warn(
        .lockRelease,
        reason: .renewFailed,
        payload: {'detail': e.toString()},
      );
      return true;
    }
  }

  static Future<void> _release(
    RemoteObjectStore backend,
    String owner,
    SyncLogger log,
  ) async {
    try {
      final current = await _read(backend);
      if (current != null && current.owner != owner) {
        log.warn(
          .lockRelease,
          reason: .releaseFailed,
          payload: {'holder': current.owner},
        );
        return;
      }
      await backend.deleteObject(SyncKeys.lockPath);
      log.info(.lockRelease);
    } catch (e) {
      log.warn(
        .lockRelease,
        reason: .releaseFailed,
        payload: {'detail': e.toString()},
      );
    }
  }

  static Future<void> _acquire(
    RemoteObjectStore backend,
    String owner,
    SyncLogger log,
  ) async {
    final backendId = backend.persistentBackendId;
    var unreadable = 0;
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      final payload = LeasePayload(
        owner: owner,
        acquiredAt: .timestamp(),
        ttl: ttl,
      );
      final outcome = await _claim(backend, payload, backendId, log);
      if (outcome == .created) {
        unreadable = 0;
        if (backendId != null && _casVerified[backendId] == true) {
          log.info(
            .lockAcquire,
            reason: .casVerified,
            payload: {'owner': owner, 'attempt': attempt},
          );
          return;
        }
        await Future.delayed(
          readbackSettleDelay ??
              Duration(milliseconds: 150 + _random.nextInt(250)),
        );
        final verify = await _read(backend);
        if (verify != null && verify.owner == owner) {
          log.info(.lockAcquire, payload: {'owner': owner, 'attempt': attempt});
          if (backendId != null && !_casVerified.containsKey(backendId)) {
            await _probeCas(backend, backendId, owner, log);
          }
          return;
        }
      } else {
        final existing = await _read(backend);
        if (existing == null) {
          unreadable++;
          if (unreadable >= 2) {
            unreadable = 0;
            await backend.deleteObject(SyncKeys.lockPath);
          }
        } else {
          unreadable = 0;
          if (existing.owner == owner) {
            await backend.writeObject(SyncKeys.lockPath, payload.toBytes());
            log.info(
              .lockAcquire,
              reason: .takeover,
              payload: {'owner': owner},
            );
            return;
          }
          if (existing.isExpired(.timestamp())) {
            log.warn(
              .lockAcquire,
              reason: .expiredLock,
              payload: {
                'holder': existing.owner,
                'acquiredAt': existing.acquiredAt.toIso8601String(),
              },
            );
            await backend.deleteObject(SyncKeys.lockPath);
            continue;
          }
        }
      }
      if (attempt < _maxAttempts) {
        await Future.delayed(_retryDelay);
      }
    }
    throw SyncException(l10n.sync.errLocked, kind: .locked);
  }

  static Future<void> _probeCas(
    RemoteObjectStore backend,
    String backendId,
    String owner,
    SyncLogger log,
  ) async {
    try {
      final outcome = await backend.tryCreateExclusive(
        SyncKeys.lockPath,
        LeasePayload(
          owner: owner,
          acquiredAt: .timestamp(),
          ttl: ttl,
        ).toBytes(),
      );
      final atomic = outcome == ExclusiveCreate.exists;
      _casVerified[backendId] = atomic;
      if (!atomic) {
        log.warn(
          .lockAcquire,
          reason: .casUnsupported,
          payload: {'backendId': backendId},
        );
      } else {
        log.info(
          .lockAcquire,
          reason: .casVerified,
          payload: {'backendId': backendId},
        );
      }
    } catch (_) {}
  }

  static Future<ExclusiveCreate> _claim(
    RemoteObjectStore backend,
    LeasePayload payload,
    String? backendId,
    SyncLogger log,
  ) async {
    final bytes = payload.toBytes();
    if (backendId != null && _casVerified[backendId] == true) {
      return backend.tryCreateExclusive(SyncKeys.lockPath, bytes);
    }
    if (await backend.readObject(SyncKeys.lockPath) != null) return .exists;
    if (backendId != null && _casVerified[backendId] == false) {
      await backend.writeObject(SyncKeys.lockPath, bytes);
      return .created;
    }
    final outcome = await backend.tryCreateExclusive(SyncKeys.lockPath, bytes);
    if (outcome != ExclusiveCreate.unsupported) return outcome;
    await backend.writeObject(SyncKeys.lockPath, bytes);
    if (backendId != null) {
      log.warn(
        .lockAcquire,
        reason: .casUnsupported,
        payload: {'backendId': backendId},
      );
      _casVerified[backendId] = false;
    }
    return .created;
  }
}
