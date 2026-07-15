import 'package:flutter/foundation.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:nsd/nsd.dart' as nsd;

/// mDNS/Bonjour 发现层（nsd 插件包装）。发现是纯增强：任何一步失败都静默降级，
/// 手动「IP + 配对码」路径始终可用。iOS 需要 Info.plist 的 `NSBonjourServices`
/// 列出 [lanServiceType]，否则浏览会静默返回空。
const String lanServiceType = '_moodiary._tcp';

/// 接收端：把本机服务广播到局域网（服务名 = 设备名，端口 = 实际监听端口）。
class LanAdvertiser {
  nsd.Registration? _registration;

  Future<void> start({required int port}) async {
    if (_registration != null) return;
    try {
      _registration = await nsd.register(
        nsd.Service(
          name: 'Moodiary · ${await PackageUtil.getDeviceName()}',
          type: lanServiceType,
          port: port,
        ),
      );
    } catch (_) {
      // 广播失败不影响接收：对方仍可手动输入 IP。
    }
  }

  Future<void> stop() async {
    final registration = _registration;
    _registration = null;
    if (registration != null) {
      try {
        await nsd.unregister(registration);
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
  nsd.Discovery? _discovery;

  final ValueNotifier<List<LanPeer>> peers = ValueNotifier(const []);

  Future<void> start() async {
    if (_discovery != null) return;
    try {
      // ipLookupType：把主机名解析成数字 IP —— `.local` 主机名在 Android 的
      // 标准 DNS 解析里不可用，直连必须用 IP。
      final discovery = await nsd.startDiscovery(
        lanServiceType,
        ipLookupType: nsd.IpLookupType.v4,
      );
      _discovery = discovery;
      discovery.addListener(_update);
    } catch (_) {
      // 浏览失败（权限被拒 / 平台不支持）→ 列表保持为空，走手动输入。
    }
  }

  void _update() {
    final services = _discovery?.services ?? const <nsd.Service>[];
    peers.value = [
      for (final service in services)
        if (service.port != null)
          if (_hostOf(service) case final String host)
            LanPeer(
              name: service.name ?? host,
              host: host,
              port: service.port!,
            ),
    ];
  }

  static String? _hostOf(nsd.Service service) {
    final addresses = service.addresses;
    if (addresses != null && addresses.isNotEmpty) {
      return addresses.first.address;
    }
    return null;
  }

  Future<void> stop() async {
    final discovery = _discovery;
    _discovery = null;
    if (discovery != null) {
      discovery.removeListener(_update);
      try {
        await nsd.stopDiscovery(discovery);
      } catch (_) {}
    }
  }
}
