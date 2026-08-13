import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_sync/src/data/model/sync_provider.dart';

import '../../sync_test_harness.dart';

void main() {
  setUp(() async => setUpSyncEnv());
  tearDown(tearDownSyncEnv);

  test('fromValue maps known values and falls back to webdav', () {
    expect(SyncProviderType.fromValue('webdav'), SyncProviderType.webdav);
    expect(SyncProviderType.fromValue('s3'), SyncProviderType.s3);
    expect(SyncProviderType.fromValue(null), SyncProviderType.webdav);
    expect(SyncProviderType.fromValue('unknown'), SyncProviderType.webdav);
  });

  test('current defaults to webdav and follows setCurrent', () async {
    expect(SyncProviderType.current(), SyncProviderType.webdav);
    SyncProviderType.setCurrent(.s3);
    expect(SyncProviderType.current(), SyncProviderType.s3);
    expect(MoodiaryKVs.syncProvider.get(), 's3');
  });
}
