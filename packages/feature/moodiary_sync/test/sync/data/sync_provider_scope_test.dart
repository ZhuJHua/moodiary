import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_sync/src/application/sync_controller.dart';
import 'package:moodiary_sync/src/application/sync_runner.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/model/sync_provider.dart';
import 'package:moodiary_sync/src/data/remote_lease.dart';
import 'package:moodiary_sync/src/data/sync_data_providers.dart';
import 'package:moodiary_sync/src/data/sync_key_manager.dart';
import 'package:moodiary_sync/src/data/sync_keyfile.dart';

import '../sync_test_harness.dart';

void main() {
  late SyncTestEnv env;
  setUp(() async {
    env = await setUpSyncEnv();
  });
  tearDown(tearDownSyncEnv);

  group('configuredCloudBackendIds', () {
    test('is empty when nothing is configured', () async {
      expect(await env.configuredBackends(), isEmpty);
    });

    test('reflects each configured backend', () async {
      await env.configureBackend(.webdav);
      expect(await env.configuredBackends(), {'webdav'});
      await env.configureBackend(.s3);
      expect(await env.configuredBackends(), {'webdav', 's3'});
    });
  });

  test(
    'switching keeps the old backend and resets connection health',
    () async {
      final old = env.container.read(activeSyncBackendProvider);
      final controller = env.container.read(syncControllerProvider.notifier);
      await env.guard.tryWithOperation(
        (operation) => controller.probe(operation, FakeRemoteBackend()),
      );
      expect(
        env.container.read(syncControllerProvider).health,
        SyncHealth.reachable,
      );
      final probeBackend = FakeRemoteBackend();
      Future<int> claimCount() async {
        probeBackend.ops.clear();
        await RemoteLease.protect(
          probeBackend,
          () async {},
          logger: env.logger,
        );
        return probeBackend.opCount('create', SyncKeys.lockPath);
      }

      expect(await claimCount(), 2);
      expect(await claimCount(), 1);
      final settings = env.container.read(
        activeSyncProviderTypeProvider.notifier,
      );
      expect(settings.select(.s3), isTrue);
      expect(await claimCount(), 2);
      expect(
        env.container.read(activeSyncBackendProvider).type,
        SyncProviderType.s3,
      );
      expect(
        env.container.read(syncControllerProvider).health,
        SyncHealth.unknown,
      );
      expect(settings.select(.webdav), isTrue);
      expect(env.container.read(activeSyncBackendProvider), same(old));
    },
  );
  test(
    'changing buckets rebuilds S3 and schedules the keyfile again',
    () async {
      await env.configureBackend(.s3);
      final settings = env.container.read(
        activeSyncProviderTypeProvider.notifier,
      );
      expect(settings.select(.s3), isTrue);
      final old = env.container.read(activeSyncBackendProvider);
      expect(await old.isReady(), isTrue);
      await SyncKeyManager.storeDek(List.filled(32, 7));
      expect(SyncKeyManager.pendingUploadBackends(), isEmpty);
      const keyfile = SyncKeyfile(
        kdfMemoryKiB: 65536,
        kdfIterations: 3,
        kdfParallelism: 4,
        saltB64: 'bWluZQ==',
        wrappedDekB64: 'bWluZQ==',
      );
      SyncKeyManager.cacheKeyfile(keyfile);
      expect(
        await settings.saveOptions(.s3, [
          'https://s3.example',
          '',
          'ak',
          'sk',
          'new-bucket',
          '1',
        ]),
        isTrue,
      );
      final current = env.container.read(activeSyncBackendProvider);
      expect(current, isNot(same(old)));
      expect(await current.isReady(), isTrue);
      expect((await old.savedOptions())[4], 'bucket');
      expect((await current.savedOptions())[4], 'new-bucket');
      expect(SyncKeyManager.pendingUploadBackends(), contains('s3'));
      final newBucket = FakeRemoteBackend(backendId: 's3');
      await SyncKeyManager.uploadPendingKeyfile(newBucket);
      expect(
        newBucket.objects[SyncKeys.keysPath],
        orderedEquals(keyfile.toBytes()),
      );
      expect(SyncKeyManager.pendingUploadBackends(), isEmpty);
    },
  );
}
