import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_sync/src/data/model/sync_provider.dart';
import 'package:moodiary_sync/src/data/remote_lease.dart';
import 'package:moodiary_sync/src/data/sync.dart';

/// 「当前同步 provider」是一段会话，用 get_it scope 表达：
///
/// - 基础层由 injectable 生成：每个后端实现以 `@Named(SyncProviderIds.x)` 注册为懒单例。
/// - [activateSyncProvider] 按 KV `syncProvider` 选一个，开 [kSyncProviderScope] 把它以
///   **无名** [IRemoteSyncBackend] 注册进去。上层只写 `getIt<IRemoteSyncBackend>()`，
///   不认识名字、不认识 WebDAV 还是 S3。切换 = pop 旧 scope 再开一个。
/// - injectable 的 `@Scope` 进不了 micro-package（生成器直接拒绝），会话 scope 手写。
///
/// 激活是不可失败的操作：先解析后端（唯一可能抛的一步，缺 `@Named` 绑定在 debug 由
/// `_assertRequiredBindings` 先报）再换 scope，失败时旧 scope 原样保留。启动引导在
/// 版本迁移之后、watcher 醒来之前调用一次；main 的 try/catch 与 watcher 的 `maybeGet`
/// 只是最后防线，不是受支持的中间态。
///
/// 后端配置（SecureKV）**不在这里读**：启动只读应用锁 PIN，其余机密由后端首次用到时
/// 异步读并自缓存。
const kSyncProviderScope = 'syncProvider';

/// 全部云后端（基础层的具名懒单例，按 [SyncProviderType] 逐个取名）。
Iterable<IRemoteSyncBackend> allSyncBackends() => SyncProviderType.values.map(
  (t) => getIt<IRemoteSyncBackend>(instanceName: t.value),
);

/// 按 KV `syncProvider` 激活当前后端（启动 / 切换 provider 时调用）。
Future<void> activateSyncProvider() async {
  final backend = getIt<IRemoteSyncBackend>(
    instanceName: SyncProviderType.current().value,
  );
  if (getIt.hasScope(kSyncProviderScope)) {
    await getIt.dropScope(kSyncProviderScope);
  }
  getIt.pushNewScope(
    scopeName: kSyncProviderScope,
    // 与基础层的具名注册是同一实例、无 dispose 回调。后端不得实现 get_it 的
    // Disposable，否则 drop scope 会把共享实例释放掉。
    init: (g) => g.registerSingleton<IRemoteSyncBackend>(backend),
  );
  // 后端配置可能换了服务器（backendId 只是 provider 类型）：清掉进程内的
  // 条件写探测结论，下次抢占重新探测。
  RemoteLease.resetCasProbeCache();
}

/// 已完成配置的云后端 id 集合。引擎据此判断 tombstone 是否覆盖所有云后端
/// （覆盖后才真正清除）。
Future<Set<String>> configuredCloudBackendIds() async => {
  for (final b in allSyncBackends())
    if (await b.isReady()) b.type.value,
};
