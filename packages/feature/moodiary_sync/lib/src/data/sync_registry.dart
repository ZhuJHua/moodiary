import 'package:injectable/injectable.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_sync/src/data/impl/s3_sync.dart';
import 'package:moodiary_sync/src/data/impl/webdav_sync.dart';
import 'package:moodiary_sync/src/data/model/sync_provider.dart';
import 'package:moodiary_sync/src/data/remote_lease.dart';
import 'package:moodiary_sync/src/data/sync.dart';

/// 当前同步后端的进程内持有者。**同时只有一个 [IRemoteSyncBackend]**：启动 /
/// 切换 provider 时调 [reload] 按 KV `syncProvider` 换持，业务侧统一走
/// `IRemoteSyncBackend.get()`。
///
/// 不用 get_it 的 register/unregister 表达「换后端」：容器只管接线（生命周期内
/// 不变的装配关系），运行时可变状态归持有者。持有者化之后，散落各处的
/// `isRegistered<IRemoteSyncBackend>()` 探测收敛成 [hasBackend] 一处。
///
/// **构造即注册，装载另算**：新实例是空持有者，[reload] 由启动引导与切换 provider
/// 的界面显式调用 —— 「什么时候按 KV 换持」是编排，不是接线。未装载时读 [backend]
/// 抛 [StateError]。
@singleton
class RemoteSyncRegistry {
  RemoteSyncRegistry();

  static RemoteSyncRegistry get() => getIt<RemoteSyncRegistry>();

  IRemoteSyncBackend? _backend;

  bool get hasBackend => _backend != null;

  /// 当前后端；未装载时抛 [StateError]。
  IRemoteSyncBackend get backend {
    final backend = _backend;
    if (backend == null) {
      throw StateError('RemoteSyncRegistry: 尚未 reload，无可用后端');
    }
    return backend;
  }

  /// 启动 / 切换 provider 时按 KV `syncProvider` 换持。
  Future<void> reload() async {
    // SecureKV 是异步的，而 isReady / isConfigured 是同步 getter：在这里把两个后端的
    // 配置都读进进程内缓存，之后同步读。两个都读是因为 configuredCloudBackendIds()
    // 不论当前持有的是哪个都要查。
    await Future.wait([
      WebDavSyncBackend.options.load(),
      S3SyncBackend.options.load(),
    ]);
    _backend = switch (SyncProviderType.current()) {
      .webdav => WebDavSyncBackend(),
      .s3 => S3SyncBackend(),
    };
    // 后端配置可能换了服务器（backendId 只是 provider 类型）：清掉进程内的
    // 条件写探测结论，下次抢占重新探测。
    RemoteLease.resetCasProbeCache();
  }
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
