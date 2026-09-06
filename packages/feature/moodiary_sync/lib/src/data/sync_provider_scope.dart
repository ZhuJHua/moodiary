import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_sync/src/data/model/sync_provider.dart';
import 'package:moodiary_sync/src/data/remote_lease.dart';
import 'package:moodiary_sync/src/data/sync.dart';

const kSyncProviderScope = 'syncProvider';

Iterable<IRemoteSyncBackend> allSyncBackends() => SyncProviderType.values.map(
  (t) => getIt<IRemoteSyncBackend>(instanceName: t.value),
);

Future<void> activateSyncProvider() async {
  final backend = getIt<IRemoteSyncBackend>(
    instanceName: SyncProviderType.current().value,
  );
  if (getIt.hasScope(kSyncProviderScope)) {
    await getIt.dropScope(kSyncProviderScope);
  }
  getIt.pushNewScope(
    scopeName: kSyncProviderScope,
    // 后端不得实现 Disposable，否则 dropScope 会释放共享实例
    init: (g) => g.registerSingleton<IRemoteSyncBackend>(backend),
  );
  RemoteLease.resetCasProbeCache();
}

Future<Set<String>> configuredCloudBackendIds() async => {
  for (final b in allSyncBackends())
    if (await b.isReady()) b.type.value,
};
