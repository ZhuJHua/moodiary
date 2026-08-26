import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';
import 'package:moodiary_platform/moodiary_platform.dart';

/// mDNS/Bonjour 发现层（bonsoir 插件包装）。发现是纯增强：任何一步失败都静默降级，
/// 手动「IP + 配对码」路径始终可用。iOS 需要 Info.plist 的 `NSBonjourServices`
/// 列出 [lanServiceType]，否则浏览会静默返回空。
const String lanServiceType = '_moodiary._tcp';

/// 接收端：把本机服务广播到局域网（服务名 = 设备名，端口 = 实际监听端口）。
class LanAdvertiser {
  BonsoirBroadcast? _broadcast;

  Future<void> start({required int port}) async {
    if (_broadcast != null) return;
    try {
      final broadcast = BonsoirBroadcast(
        service: BonsoirService(
          name: 'Moodiary · ${await AppInfo.getDeviceName()}',
          type: lanServiceType,
          port: port,
        ),
      );
      _broadcast = broadcast;
      await broadcast.initialize();
      await broadcast.start();
    } catch (_) {
      // 广播失败不影响接收：对方仍可手动输入 IP。
      _broadcast = null;
    }
  }

  Future<void> stop() async {
    final broadcast = _broadcast;
    _broadcast = null;
    if (broadcast != null) {
      try {
        await broadcast.stop();
      } catch (_) {}
    }
  }
}

/// 发现到的接收端。
class LanPeer {
  final String name;
  final String host;
  final int port;

  const LanPeer({required this.name, required this.host, required this.port});
}

/// 发送端：浏览局域网内的接收端，结果经 [peers] 通知 UI。
class LanBrowser {
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _subscription;

  /// 服务名 → 已解析的对端。bonsoir 逐事件推送，这里自己维持全量列表。
  final Map<String, LanPeer> _found = {};

  final ValueNotifier<List<LanPeer>> peers = ValueNotifier(const []);

  Future<void> start() async {
    if (_discovery != null) return;
    try {
      final discovery = BonsoirDiscovery(type: lanServiceType);
      _discovery = discovery;
      await discovery.initialize();
      // 先订阅再 start，否则会漏掉启动瞬间就已在网的服务。
      _subscription = discovery.eventStream?.listen(_onEvent);
      await discovery.start();
    } catch (_) {
      // 浏览失败（权限被拒 / 平台不支持）→ 列表保持为空，走手动输入。
      _discovery = null;
    }
  }

  void _onEvent(BonsoirDiscoveryEvent event) {
    switch (event) {
      // found 只有名字，必须显式 resolve 才会带回 hostAddresses。
      case BonsoirDiscoveryServiceFoundEvent(:final service):
        final resolver = _discovery?.serviceResolver;
        if (resolver != null) {
          unawaited(
            Future.sync(() => service.resolve(resolver)).catchError((_) {}),
          );
        }
      case BonsoirDiscoveryServiceResolvedEvent(:final service) ||
          BonsoirDiscoveryServiceUpdatedEvent(:final service):
        if (_hostOf(service) case final String host) {
          _found[service.name] = LanPeer(
            name: service.name,
            host: host,
            port: service.port,
          );
          _publish();
        }
      case BonsoirDiscoveryServiceLostEvent(:final service):
        if (_found.remove(service.name) != null) _publish();
      default:
        break;
    }
  }

  void _publish() => peers.value = List.unmodifiable(_found.values);

  /// 直连要数字 IP —— `.local` 主机名在 Android 的标准 DNS 解析里不可用，
  /// 所以只认 hostAddresses，且优先 IPv4。
  static String? _hostOf(BonsoirService service) {
    final addresses = service.hostAddresses;
    if (addresses.isEmpty) return null;
    for (final address in addresses) {
      if (!address.contains(':')) return address;
    }
    return null;
  }

  Future<void> stop() async {
    final discovery = _discovery;
    final subscription = _subscription;
    _discovery = null;
    _subscription = null;
    _found.clear();
    _publish();
    await subscription?.cancel();
    if (discovery != null) {
      try {
        await discovery.stop();
      } catch (_) {}
    }
  }
}
