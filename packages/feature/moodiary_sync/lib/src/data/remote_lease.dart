import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

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
    try {
      renewTimer = .periodic(renewInterval, (_) {
        pendingRenew = backend
            .writeObject(
              SyncKeys.lockPath,
              LeasePayload(
                owner: owner,
                acquiredAt: .timestamp(),
                ttl: ttl,
              ).toBytes(),
            )
            .catchError((Object e) {
              log.warn(
                .lockRelease,
                reason: .renewFailed,
                payload: {'detail': e.toString()},
              );
            });
      });
      return await body();
    } finally {
      renewTimer?.cancel();
      await pendingRenew;
      try {
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
  }

  static Future<void> _acquire(
    RemoteObjectStore backend,
    String owner,
    SyncLogger log,
  ) async {
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      final payload = LeasePayload(
        owner: owner,
        acquiredAt: .timestamp(),
        ttl: ttl,
      );
      final created = await backend.tryCreateExclusive(
        SyncKeys.lockPath,
        payload.toBytes(),
      );
      if (created) {
        final backendId = backend.persistentBackendId;
        if (backendId != null && _casVerified[backendId] == true) {
          log.info(
            .lockAcquire,
            reason: .casVerified,
            payload: {'owner': owner, 'attempt': attempt},
          );
          return;
        }
        await Future.delayed(
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
          await backend.deleteObject(SyncKeys.lockPath);
          continue;
        }
        if (existing.owner == owner) {
          await backend.writeObject(SyncKeys.lockPath, payload.toBytes());
          log.info(.lockAcquire, reason: .takeover, payload: {'owner': owner});
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
      final overwrote = await backend.tryCreateExclusive(
        SyncKeys.lockPath,
        LeasePayload(
          owner: owner,
          acquiredAt: .timestamp(),
          ttl: ttl,
        ).toBytes(),
      );
      _casVerified[backendId] = !overwrote;
      if (overwrote) {
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
    } catch (_) {
    }
  }
}
