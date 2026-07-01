import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary/feature/sync/data/sync.dart';
import 'package:moodiary/feature/sync/data/model/sync_provider.dart';
import 'package:moodiary/feature/sync/data/sync_registry.dart';

import '../sync_test_harness.dart';

void main() {
  setUp(() async => setUpSyncEnv());
  tearDown(tearDownSyncEnv);

  group('configuredCloudBackendIds', () {
    test('is empty when nothing is configured', () {
      expect(configuredCloudBackendIds(), isEmpty);
    });

    test('reflects each configured backend', () async {
      await configureBackend(SyncProviderType.webdav);
      expect(configuredCloudBackendIds(), {'webdav'});

      await configureBackend(SyncProviderType.s3);
      expect(configuredCloudBackendIds(), {'webdav', 's3'});
    });
  });

  group('registerRemoteSync', () {
    test('registers the backend that matches the current provider', () async {
      await SyncProviderType.setCurrent(SyncProviderType.webdav);
      await registerRemoteSync();
      expect(getIt<IRemoteSyncBackend>().type, SyncProviderType.webdav);

      // 切换 provider → 重新注册为对应后端（单注册不残留旧实例）。
      await SyncProviderType.setCurrent(SyncProviderType.s3);
      await registerRemoteSync();
      expect(getIt<IRemoteSyncBackend>().type, SyncProviderType.s3);
      expect(getIt.isRegistered<IRemoteSyncBackend>(), isTrue);
    });
  });
}
