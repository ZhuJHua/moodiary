import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_sync/src/application/sync_runner.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/incremental_engine.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_cancellation.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';

import '../sync_test_harness.dart';

void main() {
  late SyncLogger logger;
  late FakeRemoteBackend backend;
  late SyncRunner runner;

  setUp(() async {
    logger = (await setUpSyncEnv()).logger;
    await configureBackend(.webdav);
    backend = FakeRemoteBackend();
    getIt.registerSingleton<IRemoteSyncBackend>(backend);
    runner = SyncRunner.withEngine(getIt<SyncCancellation>(), logger, (
      backend, {
      trigger,
    }) async {
      if (!await backend.isReady()) throw backend.notReadyError;
      return IncrementalSyncEngine(
        backend,
        logger: logger,
        diaryStore: FakeDiaryStore(const []),
        categoryStore: FakeCategoryStore(const []),
        placeStore: FakePlaceStore(),
        mediaInfoStore: FakeMediaInfoStore(const []),
        tombstoneStore: FakeTombstoneStore(),
        mediaFiles: FakeMediaFiles(),
        cipherProvider: () async => SyncCipher.plaintext,
        concurrency: 2,
        trigger: trigger,
      );
    });
  });

  tearDown(tearDownSyncEnv);

  test('空远端 push：跑完 → 空闲，last 为 upToDate，健康可达', () async {
    final seen = <bool>[];
    runner.status.addListener(() => seen.add(runner.isRunning));

    final outcome = await runner.run(.push, trigger: .close);

    expect(outcome, isNotNull);
    expect(outcome!.kind, SyncOutcomeKind.upToDate);
    expect(outcome.trigger, SyncTrigger.close);
    expect(runner.isRunning, isFalse);
    expect(runner.status.value.last, same(outcome));
    expect(runner.status.value.health, SyncHealth.reachable);
    expect(seen.first, isTrue);
    expect(seen.last, isFalse);
  });

  test('网络类错误 → failed，health=unreachable，边沿只记一条 warn', () async {
    backend.beforeOp = (op, key) {
      throw const SyncException('[network] boom', kind: .network);
    };
    final events = <SyncEvent>[];
    final sub = logger.events.listen(events.add);
    addTearDown(sub.cancel);

    final first = await runner.run(.sync, trigger: .poll);
    final second = await runner.run(.sync, trigger: .poll);

    expect(first!.kind, SyncOutcomeKind.failed);
    expect(second!.kind, SyncOutcomeKind.failed);
    expect(runner.status.value.health, SyncHealth.unreachable);
    expect(runner.status.value.healthSince, isNotNull);
    await pumpEventQueue();
    final edges = events.where(
      (e) => e.kind == .manifestRead && e.reason == .probeFailed,
    );
    expect(edges.length, 1, reason: '重复失败不刷屏');
  });

  test('鉴权错误 → authFailed；恢复后回到 reachable 并记 recovered', () async {
    backend.beforeOp = (op, key) {
      throw const SyncException('[auth] 401', kind: .auth);
    };
    final events = <SyncEvent>[];
    final sub = logger.events.listen(events.add);
    addTearDown(sub.cancel);

    await runner.run(.sync, trigger: .manual);
    expect(runner.status.value.health, SyncHealth.authFailed);

    backend.beforeOp = null;
    await runner.run(.sync, trigger: .manual);
    expect(runner.status.value.health, SyncHealth.reachable);
    await pumpEventQueue();
    expect(events.any((e) => e.reason == .recovered), isTrue);
  });

  test('远端活着的失败（锁 / 竞争）不动健康态', () async {
    await runner.run(.push, trigger: .manual);
    backend.beforeOp = (op, key) {
      throw const SyncException('locked', kind: .locked);
    };
    final outcome = await runner.run(.sync, trigger: .poll);
    expect(outcome!.kind, SyncOutcomeKind.failed);
    expect(runner.status.value.health, SyncHealth.reachable);
  });

  test('probe：失败一律算不可达（哪怕 kind 未知），成功回到可达', () async {
    backend.beforeOp = (op, key) {
      throw const SyncException('untagged');
    };
    await expectLater(
      runner.probe(trigger: .poll),
      throwsA(isA<SyncException>()),
    );
    expect(runner.status.value.health, SyncHealth.unreachable);

    backend.beforeOp = null;
    expect(await runner.probe(trigger: .resume), isNull);
    expect(runner.status.value.health, SyncHealth.reachable);
  });

  test('已在跑时再调 run 返回 null，不打断进行中的那次', () async {
    backend.beforeOp = (op, key) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    };
    final first = runner.run(.push, trigger: .manual);
    await Future<void>.delayed(Duration.zero);
    expect(await runner.run(.push, trigger: .change), isNull);
    expect((await first)!.kind, SyncOutcomeKind.upToDate);
  });

  test('resetHealth 回到 unknown 并清明细', () async {
    backend.beforeOp = (op, key) {
      throw const SyncException('[server] 503', kind: .server);
    };
    await runner.run(.sync, trigger: .poll);
    expect(runner.status.value.healthDetail, isNotNull);
    runner.resetHealth();
    expect(runner.status.value.health, SyncHealth.unknown);
    expect(runner.status.value.healthDetail, isNull);
  });
}
