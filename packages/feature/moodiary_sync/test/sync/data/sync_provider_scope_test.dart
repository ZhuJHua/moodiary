import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_sync/src/data/model/sync_provider.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_provider_scope.dart';

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

  group('activateSyncProvider', () {
    test('nothing is exposed before activation', () {
      expect(getIt.isRegistered<IRemoteSyncBackend>(), isFalse);
      expect(getIt.hasScope(kSyncProviderScope), isFalse);
    });

    test('exposes the backend that matches the current provider', () async {
      SyncProviderType.setCurrent(.webdav);
      await activateSyncProvider();
      expect(getIt<IRemoteSyncBackend>().type, SyncProviderType.webdav);
      // 切换 provider → 旧 scope 被 pop，新 scope 只有对应后端（无残留）。
      SyncProviderType.setCurrent(.s3);
      await activateSyncProvider();
      expect(getIt<IRemoteSyncBackend>().type, SyncProviderType.s3);
      expect(getIt.hasScope(kSyncProviderScope), isTrue);
    });

    test('activation is idempotent', () async {
      SyncProviderType.setCurrent(.webdav);
      await activateSyncProvider();
      await activateSyncProvider();
      expect(getIt<IRemoteSyncBackend>().type, SyncProviderType.webdav);
    });
  });
}
