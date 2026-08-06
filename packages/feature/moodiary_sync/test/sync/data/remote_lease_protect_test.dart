import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/remote_lease.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';

import '../sync_test_harness.dart';

/// RemoteLease.protect 的跨设备互斥逻辑：用 fake_async 推进 jitter / 重试 / 续租
/// 定时器。注意 isExpired 用 DateTime.timestamp()（真实时钟，fakeAsync 不伪造），
/// 故过期类用例用真实「过去时间」构造，不依赖 fake elapsed。
void main() {
  late SyncLogger logger;

  setUp(() async {
    logger = (await setUpSyncEnv()).logger; // 预置 deviceId='test-device'
  });
  tearDown(tearDownSyncEnv);

  test('acquires the lock, runs body, then releases it', () {
    fakeAsync((async) {
      final backend = FakeRemoteBackend();
      var ran = false;
      int? result;
      RemoteLease.protect(backend, () async {
        ran = true;
        return 7;
      }, logger: logger).then((v) => result = v);

      async.elapse(const Duration(seconds: 1)); // 越过 acquire 的回读 jitter
      expect(ran, isTrue);
      expect(result, 7);
      expect(backend.hasObject(SyncKeys.lockPath), isFalse, reason: '结束应释放锁');
    });
  });

  test('takes over its own residual lock without contention', () {
    fakeAsync((async) {
      final backend = FakeRemoteBackend();
      backend.objects[SyncKeys.lockPath] = LeasePayload(
        owner: 'test-device',
        acquiredAt: DateTime.now().toUtc(),
        ttl: RemoteLease.ttl,
      ).toBytes();

      var ran = false;
      RemoteLease.protect(backend, () async => ran = true, logger: logger);
      async.elapse(const Duration(seconds: 1));
      expect(ran, isTrue);
    });
  });

  test('clears an expired foreign lock and acquires', () {
    fakeAsync((async) {
      final backend = FakeRemoteBackend();
      backend.objects[SyncKeys.lockPath] = LeasePayload(
        owner: 'other-device',
        acquiredAt: DateTime.now().toUtc().subtract(
          const Duration(minutes: 30),
        ),
        ttl: RemoteLease.ttl,
      ).toBytes();

      var ran = false;
      RemoteLease.protect(backend, () async => ran = true, logger: logger);
      async.elapse(const Duration(seconds: 1));
      expect(ran, isTrue, reason: '过期外部锁应被清除后抢占');
    });
  });

  test('throws SyncException when another device holds an active lock', () {
    fakeAsync((async) {
      final backend = FakeRemoteBackend();
      final foreign = LeasePayload(
        owner: 'other-device',
        acquiredAt: DateTime.now().toUtc(),
        ttl: RemoteLease.ttl,
      ).toBytes();
      backend.objects[SyncKeys.lockPath] = foreign;

      Object? error;
      var bodyRan = false;
      RemoteLease.protect(backend, () async {
        bodyRan = true;
        return 0;
      }, logger: logger).catchError((Object e) {
        error = e;
        return 0;
      });

      async.elapse(const Duration(seconds: 20)); // 越过 4 次重试
      expect(error, isA<SyncException>());
      expect(bodyRan, isFalse);
      // 别人的活跃锁绝不能被动过。
      expect(
        LeasePayload.fromBytes(backend.objects[SyncKeys.lockPath]!)!.owner,
        'other-device',
      );
    });
  });

  test('renews the lease during a long body and releases at the end', () {
    fakeAsync((async) {
      final backend = FakeRemoteBackend();
      final completer = Completer<int>();
      RemoteLease.protect(backend, () => completer.future, logger: logger);

      async.elapse(const Duration(seconds: 1)); // acquire
      final before = backend.opCount('write', SyncKeys.lockPath);
      async.elapse(const Duration(seconds: 101)); // 越过一个续租周期(100s)
      expect(
        backend.opCount('write', SyncKeys.lockPath),
        greaterThan(before),
        reason: '长同步期间应续租',
      );

      completer.complete(1);
      async.elapse(const Duration(seconds: 1));
      expect(backend.hasObject(SyncKeys.lockPath), isFalse);
    });
  });

  group('conditional-put probe', () {
    test('探测通过（合规服务器）→ 第二次抢占免回读、不再重复探测', () {
      fakeAsync((async) {
        final backend = FakeRemoteBackend();
        RemoteLease.protect(backend, () async {}, logger: logger);
        async.elapse(const Duration(seconds: 1));
        expect(
          backend.opCount('read', SyncKeys.lockPath),
          1,
          reason: '首次抢占仍做回读校验',
        );
        expect(
          backend.opCount('create', SyncKeys.lockPath),
          2,
          reason: '回读通过后追加一次条件写探测',
        );

        RemoteLease.protect(backend, () async {}, logger: logger);
        async.elapse(const Duration(seconds: 1));
        expect(
          backend.opCount('read', SyncKeys.lockPath),
          1,
          reason: '探测通过后免回读',
        );
        expect(
          backend.opCount('create', SyncKeys.lockPath),
          3,
          reason: '结论已缓存，不再探测',
        );
        expect(backend.hasObject(SyncKeys.lockPath), isFalse);
      });
    });

    test('不合规服务器（覆盖写）→ 每次抢占保留回读校验', () {
      fakeAsync((async) {
        final backend = FakeRemoteBackend()..conditionalPutHonored = false;
        RemoteLease.protect(backend, () async {}, logger: logger);
        async.elapse(const Duration(seconds: 1));
        expect(backend.opCount('read', SyncKeys.lockPath), 1);

        RemoteLease.protect(backend, () async {}, logger: logger);
        async.elapse(const Duration(seconds: 1));
        expect(
          backend.opCount('read', SyncKeys.lockPath),
          2,
          reason: '不合规服务器不得免除回读',
        );
        expect(
          backend.hasObject(SyncKeys.lockPath),
          isFalse,
          reason: '探测载荷是本机合法租约，释放不受影响',
        );
      });
    });
  });
}
