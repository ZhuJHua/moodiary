import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_sync/src/data/model/sync_provider.dart';
import 'package:moodiary_sync/src/data/sync_registry.dart';

import '../sync_test_harness.dart';

void main() {
  setUp(() async => setUpSyncEnv());
  tearDown(tearDownSyncEnv);

  group('configuredCloudBackendIds', () {
    test('is empty when nothing is configured', () {
      expect(configuredCloudBackendIds(), isEmpty);
    });

    test('reflects each configured backend', () async {
      await configureBackend(.webdav);
      expect(configuredCloudBackendIds(), {'webdav'});

      await configureBackend(.s3);
      expect(configuredCloudBackendIds(), {'webdav', 's3'});
    });
  });

  group('RemoteSyncRegistry', () {
    test('holds the backend that matches the current provider', () async {
      SyncProviderType.setCurrent(.webdav);
      await RemoteSyncRegistry.get().reload();
      expect(RemoteSyncRegistry.get().backend.type, SyncProviderType.webdav);

      // 切换 provider → 换持为对应后端（单持有不残留旧实例）。
      SyncProviderType.setCurrent(.s3);
      await RemoteSyncRegistry.get().reload();
      expect(RemoteSyncRegistry.get().backend.type, SyncProviderType.s3);
      expect(RemoteSyncRegistry.get().hasBackend, isTrue);
    });

    test('starts empty', () {
      expect(RemoteSyncRegistry().hasBackend, isFalse);
    });

    test('reading backend before reload throws', () {
      expect(() => RemoteSyncRegistry().backend, throwsStateError);
    });
  });
}
