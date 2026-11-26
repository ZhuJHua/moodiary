import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_sync/src/application/sync_controller.dart';
import 'package:moodiary_sync/src/application/sync_runner.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_data_providers.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';

import '../sync_test_harness.dart';

void main() {
  late SyncTestEnv env;
  late SyncLogger logger;
  late FakeRemoteBackend backend;
  late SyncController runner;
  SyncStatus status() => env.container.read(syncControllerProvider);
  Future<SyncOutcome?> run(
    SyncDirection direction, {
    required SyncTrigger trigger,
  }) => env.guard.tryWithOperation(
    (op) => runner.run(op, backend, direction, trigger),
  );
  Future<String?> probe() =>
      env.guard.tryWithOperation<String?>((op) => runner.probe(op, backend));

  setUpAll(() {
    final root = Directory.systemTemp.createTempSync('sync-runner-');
    PlatformService.get()
      ..applicationSupportPath = root.path
      ..applicationCachePath = root.path;
    addTearDown(() => root.deleteSync(recursive: true));
  });
  setUp(() async {
    backend = FakeRemoteBackend();
    env = await setUpSyncEnv(activeBackend: backend);
    logger = env.logger;
    runner = env.container.read(syncControllerProvider.notifier);
  });

  tearDown(tearDownSyncEnv);

  test('空远端 push：跑完 → 空闲，last 为 upToDate，健康可达', () async {
    final seen = <bool>[];
    env.container.listen(
      syncControllerProvider,
      (_, next) => seen.add(next.running != null),
    );

    final outcome = await run(.push, trigger: .close);

    expect(outcome, isNotNull);
    expect(outcome!.kind, SyncOutcomeKind.upToDate);
    expect(outcome.trigger, SyncTrigger.close);
    expect(status().running != null, isFalse);
    expect(status().last?.outcome, same(outcome));
    expect(status().health, SyncHealth.reachable);
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

    final first = await run(.sync, trigger: .poll);
    final second = await run(.sync, trigger: .poll);

    expect(first!.kind, SyncOutcomeKind.failed);
    expect(second!.kind, SyncOutcomeKind.failed);
    expect(status().health, SyncHealth.unreachable);
    expect(status().healthSince, isNotNull);
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

    await run(.sync, trigger: .manual);
    expect(status().health, SyncHealth.authFailed);

    backend.beforeOp = null;
    await run(.sync, trigger: .manual);
    expect(status().health, SyncHealth.reachable);
    await pumpEventQueue();
    expect(events.any((e) => e.reason == .recovered), isTrue);
  });

  test('远端活着的失败（锁 / 竞争）不动健康态', () async {
    await run(.push, trigger: .manual);
    backend.beforeOp = (op, key) {
      throw const SyncException('locked', kind: .locked);
    };
    final outcome = await run(.sync, trigger: .poll);
    expect(outcome!.kind, SyncOutcomeKind.failed);
    expect(status().health, SyncHealth.reachable);
  });

  test('probe：失败一律算不可达（哪怕 kind 未知），成功回到可达', () async {
    backend.beforeOp = (op, key) {
      throw const SyncException('untagged');
    };
    await expectLater(probe(), throwsA(isA<SyncException>()));
    expect(status().health, SyncHealth.unreachable);

    backend.beforeOp = null;
    expect(await probe(), isNull);
    expect(status().health, SyncHealth.reachable);
  });

  test('已在跑时再调 run 返回 null，不打断进行中的那次', () async {
    final release = Completer<bool>();
    final first = runner.sync(prepare: (_, _) => release.future);
    expect(await run(.push, trigger: .change), isNull);
    final settings = env.container.read(
      activeSyncProviderTypeProvider.notifier,
    );
    expect(await settings.saveOptions(.s3, ['blocked']), isFalse);
    expect(await settings.clearOptions(.webdav), isFalse);
    expect(settings.select(.s3), isFalse);
    release.complete(true);
    expect((await first)!.kind, SyncOutcomeKind.upToDate);
  });

  test(
    'stopping the current push does not cancel the following push',
    () async {
      final first = runner.push();
      runner.stop();
      expect((await first)?.kind, SyncOutcomeKind.stopped);
      expect((await runner.push())?.kind, SyncOutcomeKind.upToDate);
    },
  );

  test('resetHealth 回到 unknown 并清明细', () async {
    backend.beforeOp = (op, key) {
      throw const SyncException('[server] 503', kind: .server);
    };
    await run(.sync, trigger: .poll);
    expect(status().healthDetail, isNotNull);
    runner.resetHealth();
    expect(status().health, SyncHealth.unknown);
    expect(status().healthDetail, isNull);
  });
}
