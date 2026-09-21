import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';
import 'package:moodiary_sync/src/data/remote_lease.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';

import '../sync_test_harness.dart';

void main() {
  late SyncLogger logger;

  setUp(() async {
    logger = (await setUpSyncEnv()).logger;
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

      async.elapse(const Duration(seconds: 1));
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

      async.elapse(const Duration(seconds: 20));
      expect(error, isA<SyncException>());
      expect(bodyRan, isFalse);
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

      async.elapse(const Duration(seconds: 1));
      final before = backend.opCount('write', SyncKeys.lockPath);
      async.elapse(const Duration(seconds: 101));
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

  test('释放前确认归属：锁已易主则不删对方的锁', () {
    fakeAsync((async) {
      final backend = FakeRemoteBackend();
      final foreign = LeasePayload(
        owner: 'other-device',
        acquiredAt: DateTime.now().toUtc(),
        ttl: RemoteLease.ttl,
      ).toBytes();

      RemoteLease.protect(backend, () async {
        backend.objects[SyncKeys.lockPath] = foreign;
      }, logger: logger);
      async.elapse(const Duration(seconds: 1));

      expect(
        LeasePayload.fromBytes(backend.objects[SyncKeys.lockPath]!)!.owner,
        'other-device',
        reason: '本机租约已被接管，释放不得删除对方的锁',
      );
    });
  });

  test('续租前确认归属：锁已易主则停止续租，也不再覆盖对方', () {
    fakeAsync((async) {
      final backend = FakeRemoteBackend();
      final completer = Completer<int>();
      RemoteLease.protect(backend, () => completer.future, logger: logger);
      async.elapse(const Duration(seconds: 1));

      backend.objects[SyncKeys.lockPath] = LeasePayload(
        owner: 'other-device',
        acquiredAt: DateTime.now().toUtc(),
        ttl: RemoteLease.ttl,
      ).toBytes();
      final writes = backend.opCount('write', SyncKeys.lockPath);
      async.elapse(const Duration(seconds: 301));
      expect(
        backend.opCount('write', SyncKeys.lockPath),
        writes,
        reason: '续租发现锁已易主后不得再写',
      );

      completer.complete(1);
      async.elapse(const Duration(seconds: 1));
      expect(
        LeasePayload.fromBytes(backend.objects[SyncKeys.lockPath]!)!.owner,
        'other-device',
      );
    });
  });

  test('静默覆盖型服务器：能力未知时也不得盲写抢走他人的活锁', () {
    fakeAsync((async) {
      final backend = FakeRemoteBackend()..conditionalPutHonored = false;
      backend.objects[SyncKeys.lockPath] = LeasePayload(
        owner: 'other-device',
        acquiredAt: DateTime.now().toUtc(),
        ttl: RemoteLease.ttl,
      ).toBytes();

      Object? error;
      var bodyRan = false;
      RemoteLease.protect(backend, () async {
        bodyRan = true;
        return 0;
      }, logger: logger).catchError((Object e) {
        error = e;
        return 0;
      });

      async.elapse(const Duration(seconds: 20));
      expect(bodyRan, isFalse);
      expect(error, isA<SyncException>());
      expect(
        LeasePayload.fromBytes(backend.objects[SyncKeys.lockPath]!)!.owner,
        'other-device',
      );
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
          3,
          reason: '能力未知时先读一次，再回读校验，释放前再确认归属',
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
          4,
          reason: '探测通过后免预读也免回读，只剩释放前的归属确认',
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
        expect(backend.opCount('read', SyncKeys.lockPath), 3);

        RemoteLease.protect(backend, () async {}, logger: logger);
        async.elapse(const Duration(seconds: 1));
        expect(
          backend.opCount('read', SyncKeys.lockPath),
          6,
          reason: '不合规服务器不得免除预读与回读',
        );
        expect(
          backend.hasObject(SyncKeys.lockPath),
          isFalse,
          reason: '探测载荷是本机合法租约，释放不受影响',
        );
      });
    });
  });

  group('服务端拒绝条件写（阿里云 OSS 式 400 NotImplemented）', () {
    test('降级为读后写，照常拿到锁并释放，降级只记一次日志', () {
      fakeAsync((async) {
        final backend = FakeRemoteBackend()..conditionalPutSupported = false;
        final events = <SyncEvent>[];
        final sub = logger.events.listen(events.add);
        var ran = false;
        RemoteLease.protect(backend, () async => ran = true, logger: logger);
        async.elapse(const Duration(seconds: 1));
        RemoteLease.protect(backend, () async {}, logger: logger);
        async.elapse(const Duration(seconds: 1));
        sub.cancel();

        expect(ran, isTrue, reason: '条件写不可用不应让整轮同步失败');
        expect(backend.hasObject(SyncKeys.lockPath), isFalse);
        expect(
          backend.opCount('create', SyncKeys.lockPath),
          1,
          reason: '降级结论缓存后不再发注定失败的条件写',
        );
        expect(
          events
              .where((e) => e.kind == .lockAcquire && e.reason == .casUnsupported)
              .length,
          1,
          reason: '降级结论缓存后不再刷屏',
        );
      });
    });

    test('降级后仍靠回读校验判负：写入后被他人覆盖就不算持锁', () {
      fakeAsync((async) {
        final backend = FakeRemoteBackend()..conditionalPutSupported = false;
        var wroteLock = false;
        backend.beforeOp = (op, key) {
          if (key != SyncKeys.lockPath) return;
          if (op == 'write') {
            wroteLock = true;
          } else if (op == 'read' && wroteLock) {
            wroteLock = false;
            backend.objects[SyncKeys.lockPath] = LeasePayload(
              owner: 'other-device',
              acquiredAt: DateTime.now().toUtc(),
              ttl: RemoteLease.ttl,
            ).toBytes();
          }
        };

        Object? error;
        var bodyRan = false;
        RemoteLease.protect(backend, () async {
          bodyRan = true;
          return 0;
        }, logger: logger).catchError((Object e) {
          error = e;
          return 0;
        });

        async.elapse(const Duration(seconds: 20));
        expect(bodyRan, isFalse, reason: '回读看到别人的租约就不得当作抢到锁');
        expect(error, isA<SyncException>());
        expect(
          LeasePayload.fromBytes(backend.objects[SyncKeys.lockPath]!)!.owner,
          'other-device',
        );
      });
    });

    test('连普通写也被拒（只读共享）→ 报真实的写入错误，不谎称不支持条件写', () {
      fakeAsync((async) {
        final backend = FakeRemoteBackend()..conditionalPutSupported = false;
        backend.beforeOp = (op, key) {
          if (op == 'write' && key == SyncKeys.lockPath) {
            throw const SyncException('[http] 405 Method Not Allowed');
          }
        };
        final events = <SyncEvent>[];
        final sub = logger.events.listen(events.add);

        Object? error;
        RemoteLease.protect(
          backend,
          () async => 0,
          logger: logger,
        ).catchError((Object e) {
          error = e;
          return 0;
        });
        async.elapse(const Duration(seconds: 20));
        sub.cancel();

        expect(error, isA<SyncException>());
        expect(
          events.where((e) => e.reason == .casUnsupported),
          isEmpty,
          reason: '降级没走通就不得下「服务器不支持条件写」的结论',
        );
      });
    });

    test('降级也不得抢走他人仍在有效期内的锁', () {
      fakeAsync((async) {
        final backend = FakeRemoteBackend()..conditionalPutSupported = false;
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

        async.elapse(const Duration(seconds: 20));
        expect(error, isA<SyncException>());
        expect(bodyRan, isFalse);
        expect(
          LeasePayload.fromBytes(backend.objects[SyncKeys.lockPath]!)!.owner,
          'other-device',
        );
      });
    });
  });
}
