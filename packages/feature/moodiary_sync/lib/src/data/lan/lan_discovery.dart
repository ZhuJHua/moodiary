import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_sync/src/data/lan/lan_protocol.dart';

// iOS 需要 Info.plist 的 NSBonjourServices 列出这个值，否则浏览会静默返回空。
const String lanServiceType = '_moodiary._tcp';

class LanAdvertiser {
  BonsoirBroadcast? _broadcast;

  Future<void> start({required int port, required String version}) async {
    if (_broadcast != null) return;
    try {
      final broadcast = BonsoirBroadcast(
        service: BonsoirService(
          name: 'Moodiary · ${await AppInfo.getDeviceName()}',
          type: lanServiceType,
          port: port,
          attributes: lanTxtRecord(version),
        ),
      );
      _broadcast = broadcast;
      await broadcast.initialize();
      await broadcast.start();
    } catch (_) {
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

class LanPeer {
  final String name;
  final String host;
  final int port;

  final int? proto;

  final String? version;

  const LanPeer({
    required this.name,
    required this.host,
    required this.port,
    this.proto,
    this.version,
  });

  bool get compatible => proto == null || proto == lanProtoVersion;
}

class LanBrowser {
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _subscription;

  final Map<String, LanPeer> _found = {};

  final ValueNotifier<List<LanPeer>> peers = ValueNotifier(const []);

  Future<void> start() async {
    if (_discovery != null) return;
    try {
      final discovery = BonsoirDiscovery(type: lanServiceType);
      _discovery = discovery;
      await discovery.initialize();
      // 先订阅再 start，否则会漏掉启动瞬间已在网的服务
      _subscription = discovery.eventStream?.listen(_onEvent);
      await discovery.start();
    } catch (_) {
      _discovery = null;
    }
  }

  void _onEvent(BonsoirDiscoveryEvent event) {
    switch (event) {
      // found 事件只有名字，需显式 resolve 才带回 hostAddresses
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
            proto: int.tryParse(service.attributes['proto'] ?? ''),
            version: service.attributes['ver'],
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

  // Android 标准 DNS 解析不认 .local 主机名，只能用数字 IP（hostAddresses），优先 IPv4
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
