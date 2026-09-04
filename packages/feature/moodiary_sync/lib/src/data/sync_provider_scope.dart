import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
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
/// 未激活时 `getIt<IRemoteSyncBackend>()` 抛；启动引导在版本迁移之后、watcher 醒来
/// 之前调用一次，watcher 自己也用 `maybeGet` 守卫。
const kSyncProviderScope = 'syncProvider';

/// 全部云后端（基础层的具名懒单例，按 [SyncProviderType] 逐个取名）。
Iterable<IRemoteSyncBackend> allSyncBackends() => SyncProviderType.values.map(
  (t) => getIt<IRemoteSyncBackend>(instanceName: t.value),
);

/// 把每个后端的 SecureKV 配置读进进程内缓存——`isReady` 是同步 getter，靠这一步
/// 先行。启动时调一次；之后 `configure()` / `clear()` 会同步刷缓存。
///
/// 逐后端 fail-open：钥匙串故障（Keystore 失效 / 设备重启未首次解锁）时该后端缓存
/// 留空、isReady 为 false，UI 走「先去配置」分支，同步暂不可用好过启动炸死。
Future<void> loadSyncBackendOptions() =>
    Future.wait([for (final b in allSyncBackends()) _loadQuietly(b)]);

Future<void> _loadQuietly(IRemoteSyncBackend backend) async {
  try {
    await backend.loadOptions();
  } catch (e, s) {
    logger.e(
      'sync backend options load failed: ${backend.type.value}',
      error: e,
      stackTrace: s,
    );
  }
}

/// 按 KV `syncProvider` 激活当前后端（启动 / 切换 provider 时调用）。
Future<void> activateSyncProvider() async {
  if (getIt.hasScope(kSyncProviderScope)) {
    await getIt.popScopesTill(kSyncProviderScope, inclusive: true);
  }
  final backend = getIt<IRemoteSyncBackend>(
    instanceName: SyncProviderType.current().value,
  );
  getIt.pushNewScope(
    scopeName: kSyncProviderScope,
    init: (g) => g.registerSingleton<IRemoteSyncBackend>(backend),
  );
  // 后端配置可能换了服务器（backendId 只是 provider 类型）：清掉进程内的
  // 条件写探测结论，下次抢占重新探测。
  RemoteLease.resetCasProbeCache();
}

/// 已完成配置的云后端 id 集合。引擎据此判断 tombstone 是否覆盖所有云后端
/// （覆盖后才真正清除）。
Set<String> configuredCloudBackendIds() => {
  for (final b in allSyncBackends())
    if (b.isReady) b.type.value,
};
