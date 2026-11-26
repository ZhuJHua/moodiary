import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_sync/src/data/model/sync_provider.dart';
import 'package:moodiary_sync/src/data/sync_data_providers.dart';

import '../../sync_test_harness.dart';

void main() {
  late SyncTestEnv env;
  setUp(() async {
    env = await setUpSyncEnv();
  });
  tearDown(tearDownSyncEnv);

  test('fromValue maps known values and falls back to webdav', () {
    expect(SyncProviderType.fromValue('webdav'), SyncProviderType.webdav);
    expect(SyncProviderType.fromValue('s3'), SyncProviderType.s3);
    expect(SyncProviderType.fromValue(null), SyncProviderType.webdav);
    expect(SyncProviderType.fromValue('unknown'), SyncProviderType.webdav);
  });

  test('current defaults to webdav and follows setCurrent', () async {
    expect(
      env.container.read(activeSyncProviderTypeProvider),
      SyncProviderType.webdav,
    );
    env.container.read(activeSyncProviderTypeProvider.notifier).select(.s3);
    expect(
      env.container.read(activeSyncProviderTypeProvider),
      SyncProviderType.s3,
    );
    expect(MoodiaryKVs.syncProvider.get(), 's3');
  });
}
