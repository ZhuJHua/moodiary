import 'package:flutter/services.dart';
import 'package:moodiary_sync/src/data/lan/lan_discovery.dart';
import 'package:moodiary_sync/src/data/lan/lan_protocol.dart';
import 'package:moodiary_sync/src/data/lan/lan_receiver.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/presentation/widget/lan_widgets.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

class LanReceivePage extends StatefulWidget {
  const LanReceivePage({super.key});

  @override
  State<LanReceivePage> createState() => _LanReceivePageState();
}

class _LanReceivePageState extends State<LanReceivePage> {
  final LanReceiverService _service = LanReceiverService();
  final LanAdvertiser _advertiser = LanAdvertiser();
  List<String> _ips = const [];
  String? _startError;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      await _service.start();
      // mDNS 广播是纯增强，失败静默（对方仍可手动输 IP）。
      await _advertiser.start(port: _service.port);
      final ips = await NetworkStatus.getLocalIPv4s();
      if (!mounted) return;
      setState(() {
        _ready = true;
        _ips = ips;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _startError = '无法启动接收：$e');
    }
  }

  @override
  void dispose() {
    _advertiser.stop();
    _service.stop();
    super.dispose();
  }

  void _copy(String text, String tip) {
    Clipboard.setData(ClipboardData(text: text));
    toast.success(message: tip);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('局域网接收')),
      body: _startError != null
          ? Center(
              child: Padding(
                padding: const .all(24),
                child: Text(
                  _startError!,
                  style: context.theme.typography.bodyMedium.error,
                ),
              ),
            )
          : !_ready
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder(
              valueListenable: _service.state,
              builder: (context, state, _) => ListView(
                padding: const .fromLTRB(20, 8, 20, 32),
                children: [
                  Center(child: _StatusHero(state: state)),
                  const SizedBox(height: 4),
                  Center(child: _StatusLine(state: state)),
                  const SizedBox(height: 28),
                  Center(
                    child: Text(
                      '配对码',
                      style: context.theme.typography.labelLarge.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LanPinBoxes(
                    pin: _service.pin,
                    onTap: () => _copy(_service.pin, '配对码已复制'),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      '在发送设备上输入 · 轻点复制',
                      style: context.theme.typography.bodySmall.outline,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _AddressCard(
                    ips: _ips,
                    port: _service.port,
                    onCopy: (address) => _copy(address, '地址已复制'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatusHero extends StatelessWidget {
  final LanReceiveState state;

  const _StatusHero({required this.state});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final (icon, color, active) = switch (state) {
      LanReceiveWaiting() => (LucideIcons.radioTower, scheme.primary, true),
      LanReceiveReceiving() => (LucideIcons.download, scheme.primary, true),
      LanReceiveImporting() => (LucideIcons.refreshCw, scheme.primary, true),
      LanReceiveDone() => (LucideIcons.check, scheme.primary, false),
      LanReceiveFailed() => (LucideIcons.x, scheme.error, false),
    };
    return LanRipple(
      size: 168,
      active: active,
      color: color,
      child: Icon(icon, size: 34, color: color),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final LanReceiveState state;

  const _StatusLine({required this.state});

  static String _summary(SyncReport report) {
    if (report.diaryCount == 0 && report.categoryCount == 0) {
      return '内容已是最新，没有变更';
    }
    final base = '日记 ${report.diaryCount} 条 · 分类 ${report.categoryCount} 条';
    return report.failed > 0 ? '$base（${report.failed} 条失败）' : base;
  }

  @override
  Widget build(BuildContext context) {
    final typography = context.theme.typography;
    final child = switch (state) {
      LanReceiveWaiting() => Text(
        '等待发送方连接…',
        key: const ValueKey('waiting'),
        style: typography.titleMedium.onSurface,
      ),
      LanReceiveReceiving(:final received, :final total) => Column(
        key: const ValueKey('receiving'),
        children: [
          Text('正在接收', style: typography.titleMedium.onSurface),
          const SizedBox(height: 12),
          SizedBox(
            width: 220,
            child: LinearProgressIndicator(
              value: (total != null && total > 0) ? received / total : null,
              minHeight: 8,
              borderRadius: .circular(999),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            total != null
                ? '${lanFmtBytes(received)} / ${lanFmtBytes(total)}'
                : lanFmtBytes(received),
            style: typography.bodySmall.onSurfaceVariant,
          ),
        ],
      ),
      LanReceiveImporting() => Text(
        '正在保存…',
        key: const ValueKey('importing'),
        style: typography.titleMedium.onSurface,
      ),
      LanReceiveDone(:final report) => Column(
        key: const ValueKey('done'),
        children: [
          Text('接收完成', style: typography.titleMedium.onSurface),
          const SizedBox(height: 6),
          Text(
            _summary(report),
            textAlign: .center,
            style: typography.bodyMedium.onSurfaceVariant,
          ),
          const SizedBox(height: 4),
          Text('可继续接收，配对码不变', style: typography.bodySmall.outline),
        ],
      ),
      LanReceiveFailed(:final message) => Column(
        key: const ValueKey('failed'),
        children: [
          Text('接收失败', style: typography.titleMedium.error),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: .center,
            style: typography.bodySmall.error,
          ),
          const SizedBox(height: 4),
          Text('配对码不变，对方可直接重试', style: typography.bodySmall.outline),
        ],
      ),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: child,
    );
  }
}

class _AddressCard extends StatelessWidget {
  final List<String> ips;
  final int port;
  final void Function(String address) onCopy;

  const _AddressCard({
    required this.ips,
    required this.port,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    return Container(
      padding: const .all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: .circular(16),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text('本机地址', style: typography.labelLarge.onSurfaceVariant),
          const SizedBox(height: 10),
          if (ips.isEmpty)
            Text('未连接 Wi-Fi，无法获取本机地址', style: typography.bodyMedium.error)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final ip in ips)
                  _AddressChip(
                    address: port == lanDefaultPort ? ip : '$ip:$port',
                    onCopy: onCopy,
                  ),
              ],
            ),
          const SizedBox(height: 10),
          Text(
            '发送方通常会自动发现本机，也可手动输入上方地址。接收期间请保持本页打开。',
            style: typography.bodySmall.outline,
          ),
        ],
      ),
    );
  }
}

class _AddressChip extends StatelessWidget {
  final String address;
  final void Function(String address) onCopy;

  const _AddressChip({required this.address, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: .circular(10),
      child: InkWell(
        borderRadius: .circular(10),
        onTap: () => onCopy(address),
        child: Padding(
          padding: const .symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: .min,
            children: [
              Text(
                address,
                style: context.theme.typography.bodyMedium.onSurface.copyWith(
                  fontFamily: 'monospace',
                  fontFeatures: const [.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              Icon(LucideIcons.copy, size: 14, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
