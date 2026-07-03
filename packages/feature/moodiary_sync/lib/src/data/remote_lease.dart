import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:moodiary_rust/moodiary_rust.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';

/// 远端锁文件（`sync.lock`）的内容。**明文 JSON、不走 SyncCodec** —— 锁须能被
/// 任何设备（含密钥不同/未配密钥的）读取；内容只有随机设备 id 与时间戳，无敏感信息。
class LeasePayload {
  final String owner;
  final DateTime acquiredAt;
  final Duration ttl;

  const LeasePayload({
    required this.owner,
    required this.acquiredAt,
    required this.ttl,
  });

  /// 损坏 / 形态不符 → null，调用方视作残留锁清除。
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

  Uint8List toBytes() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'owner': owner,
        'acquiredAt': acquiredAt.toUtc().toIso8601String(),
        'ttlSeconds': ttl.inSeconds,
      }),
    ),
  );

  /// [skew] 容忍设备间时钟偏差 —— 宁可多等不抢早：误抢活锁的双写竞态代价更大。
  bool isExpired(DateTime now, {Duration skew = RemoteLease.clockSkewMargin}) =>
      now.isAfter(acquiredAt.add(ttl).add(skew));
}

/// 远端租约锁 —— 跨设备互斥，保证同一时刻只有一个客户端执行 push/pull/re-cipher，
/// 使 manifest 的 read-modify-write 不再有多设备 last-writer-wins 竞态。
///
/// 机制：
/// - **抢占**：[IRemoteSyncBackend.tryCreateExclusive]（`If-None-Match: *`）原子
///   创建 `sync.lock`；支持条件 PUT 的服务器上严格原子；
/// - **回读校验**：兜底不支持条件 PUT 的服务器（覆盖写也报成功）—— 创建后随机抖动
///   150~400ms 再回读 owner，不是自己即竞争失败；
/// - **接管**：owner 是本机（崩溃/释放失败残留）→ 刷新接管；
/// - **过期**：`acquiredAt + ttl + 时钟偏差余量` 已过 → 删除后重试，崩溃设备最多
///   阻塞他人一个 TTL；
/// - **续租**：持有期间每 [renewInterval] 重写 acquiredAt，长同步不被误判过期。续租
///   是无条件写：本机若曾挂起 > TTL 且锁已被他人抢走，续租会把锁夺回致短暂并行
///   （窗口极窄，接受并记录在案）；
/// - **释放**：删锁文件，best-effort（失败由 TTL + 本机接管兜底）。
///
/// 锁竞争失败抛 [SyncException]：手动同步显示给用户，AutoSyncWatcher 静默吞掉重试。
class RemoteLease {
  RemoteLease._();

  /// 锁有效期。须显著大于续租间隔，覆盖网络抖动导致的续租失败。
  static const Duration ttl = Duration(minutes: 5);

  /// 判定他人锁过期时额外容忍的设备间时钟偏差。
  static const Duration clockSkewMargin = Duration(minutes: 1);

  /// 续租间隔（约 ttl / 3）。
  static const Duration renewInterval = Duration(seconds: 100);

  /// 抢占重试次数/间隔：覆盖「对方恰好在收尾」，但手动同步最多约等 10 秒。
  static const int _maxAttempts = 4;
  static const Duration _retryDelay = Duration(seconds: 3);

  static final Random _random = Random();

  /// 本机设备 id（懒生成、持久化）。
  static Future<String> _ensureDeviceId() async {
    final existing = MoodiaryKVs.syncDeviceId.get();
    if (existing != null && existing.isNotEmpty) return existing;
    final id = uuidV4();
    await MoodiaryKVs.syncDeviceId.set(id);
    return id;
  }

  static Future<LeasePayload?> _read(IRemoteSyncBackend backend) async {
    final bytes = await backend.readObject(SyncKeys.lockPath);
    if (bytes == null) return null;
    return LeasePayload.fromBytes(bytes);
  }

  /// 在远端租约保护下执行 [body]。进程内互斥由调用方保证（引擎 `_lock` 在外层），
  /// 本类只负责跨设备互斥。
  static Future<T> protect<T>(
    IRemoteSyncBackend backend,
    Future<T> Function() body, {
    SyncLogger? logger,
  }) async {
    final log = logger ?? SyncLogger.get();
    final owner = await _ensureDeviceId();
    await _acquire(backend, owner, log);

    Timer? renewTimer;
    // 最近一次在飞的续租写。释放前必须先等它落定：Timer.cancel() 拦不住已发出的
    // 请求，若续租在 deleteObject 之后才落盘，会把刚释放的锁复活成孤儿，他人白等一个 TTL。
    Future<void>? pendingRenew;
    try {
      renewTimer = Timer.periodic(renewInterval, (_) {
        pendingRenew = backend
            .writeObject(
              SyncKeys.lockPath,
              LeasePayload(
                owner: owner,
                acquiredAt: DateTime.timestamp(),
                ttl: ttl,
              ).toBytes(),
            )
            .catchError((Object e) {
              // 单次续租失败可容忍（TTL >> 续租间隔）；连续失败超过 TTL 才有被抢占风险。
              log.warn(
                SyncEventKind.lockRelease,
                '同步锁续租失败（将于下个周期重试）',
                payload: {'detail': e.toString()},
              );
            });
      });
      return await body();
    } finally {
      renewTimer?.cancel();
      await pendingRenew; // 错误已在 catchError 消化，这里只等落定
      try {
        await backend.deleteObject(SyncKeys.lockPath);
        log.info(SyncEventKind.lockRelease, '释放同步锁');
      } catch (e) {
        // best-effort：残留锁由「本机接管」或 TTL 过期兜底。
        log.warn(
          SyncEventKind.lockRelease,
          '释放同步锁失败（TTL 兜底）',
          payload: {'detail': e.toString()},
        );
      }
    }
  }

  static Future<void> _acquire(
    IRemoteSyncBackend backend,
    String owner,
    SyncLogger log,
  ) async {
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      final payload = LeasePayload(
        owner: owner,
        acquiredAt: DateTime.timestamp(),
        ttl: ttl,
      );
      final created = await backend.tryCreateExclusive(
        SyncKeys.lockPath,
        payload.toBytes(),
      );
      if (created) {
        // 回读校验：兜底不支持条件 PUT 的服务器（见类文档）。
        await Future.delayed(
          Duration(milliseconds: 150 + _random.nextInt(250)),
        );
        final verify = await _read(backend);
        if (verify != null && verify.owner == owner) {
          log.info(
            SyncEventKind.lockAcquire,
            '获得同步锁',
            payload: {'owner': owner, 'attempt': attempt},
          );
          return;
        }
        // 创建后被并发覆盖 → 竞争失败，走等待重试。
      } else {
        final existing = await _read(backend);
        if (existing == null) {
          // 锁存在但读不到 / 内容损坏 → 视作残留，清掉重试。
          await backend.deleteObject(SyncKeys.lockPath);
          continue;
        }
        if (existing.owner == owner) {
          // 本机残留（上次崩溃 / 释放失败）→ 刷新接管。
          await backend.writeObject(SyncKeys.lockPath, payload.toBytes());
          log.info(
            SyncEventKind.lockAcquire,
            '接管本机残留的同步锁',
            payload: {'owner': owner},
          );
          return;
        }
        if (existing.isExpired(DateTime.timestamp())) {
          log.warn(
            SyncEventKind.lockAcquire,
            '清除过期同步锁（holder: ${existing.owner}）',
            payload: {
              'holder': existing.owner,
              'acquiredAt': existing.acquiredAt.toIso8601String(),
            },
          );
          await backend.deleteObject(SyncKeys.lockPath);
          continue; // 立即重试抢占（删除后仍走原子创建，不会双赢）
        }
      }
      if (attempt < _maxAttempts) {
        await Future.delayed(_retryDelay);
      }
    }
    throw const SyncException('另一台设备正在同步，请稍后再试');
  }
}
