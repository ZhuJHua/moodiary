import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary/feature/sync/data/impl/s3_sync.dart';
import 'package:moodiary/feature/sync/data/sync.dart';
import 'package:moodiary/feature/sync/data/model/sync_provider.dart';
import 'package:moodiary/feature/sync/data/impl/webdav_sync.dart';

/// 同步后端的 DI 注册器。**同时只注入一个 [IRemoteSyncBackend]**：启动 / 切换
/// provider 时按 KV `syncProvider` 重新注册。业务侧统一走 `IRemoteSyncBackend.get()`。
Future<void> registerRemoteSync() async {
  if (getIt.isRegistered<IRemoteSyncBackend>()) {
    await getIt.unregister<IRemoteSyncBackend>();
  }
  final type = SyncProviderType.current();
  final backend = switch (type) {
    SyncProviderType.webdav => WebDavSyncBackend(),
    SyncProviderType.s3 => S3SyncBackend(),
  };
  getIt.registerSingleton<IRemoteSyncBackend>(backend);
}

/// KV 中已完成配置的云后端集合。引擎据此判断 tombstone 是否覆盖所有云后端
/// （覆盖后才从 Isar 真正清除）。
Set<String> configuredCloudBackendIds() {
  final ids = <String>{};
  if (WebDavSyncBackend.isConfigured()) {
    ids.add(SyncProviderType.webdav.value);
  }
  if (S3SyncBackend.isConfigured()) {
    ids.add(SyncProviderType.s3.value);
  }
  return ids;
}
