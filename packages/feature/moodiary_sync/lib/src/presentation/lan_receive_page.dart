import 'package:flutter/services.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_sync/src/data/lan/lan_discovery.dart';
import 'package:moodiary_sync/src/data/lan/lan_protocol.dart';
import 'package:moodiary_sync/src/data/lan/lan_receiver.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/presentation/widget/lan_widgets.dart';
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
      setState(() => _startError = l10n.sync.lanStartFailed(error: '$e'));
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
      appBar: AppBar(title: Text(context.l10n.sync.lanReceiveTitle)),
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
                      context.l10n.sync.lanPin,
                      style:
                          context.theme.typography.labelLarge.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LanPinBoxes(
                    pin: _service.pin,
                    onTap: () =>
                        _copy(_service.pin, context.l10n.sync.lanPinCopied),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      context.l10n.sync.lanPinHelp,
                      style: context.theme.typography.bodySmall.outline,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _AddressCard(
                    ips: _ips,
                    port: _service.port,
                    onCopy: (address) =>
                        _copy(address, context.l10n.sync.lanAddressCopied),
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
    // failed 与 cancelled 都要看：媒体全失败、或用户中途取消而条目零变更时，
    // 只看两个 count 会报「已是最新」——半截接收被说成什么都不缺。
    if (report.diaryCount == 0 &&
        report.categoryCount == 0 &&
        report.failed == 0 &&
        !report.cancelled) {
      return l10n.sync.lanUpToDate;
    }
    final base = l10n.sync.lanReceived(
      diary: report.diaryCount,
      category: report.categoryCount,
    );
    return report.failed > 0
        ? l10n.sync.lanReceivedFailed(base: base, failed: report.failed)
        : base;
  }

  @override
  Widget build(BuildContext context) {
    final typography = context.theme.typography;
    final child = switch (state) {
      LanReceiveWaiting() => Text(
        context.l10n.sync.lanWaiting,
        key: const ValueKey('waiting'),
        style: typography.titleMedium.onSurface,
      ),
      LanReceiveReceiving(:final received, :final total) => Column(
        key: const ValueKey('receiving'),
        children: [
          Text(
            context.l10n.sync.lanReceiving,
            style: typography.titleMedium.onSurface,
          ),
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
        context.l10n.sync.lanSaving,
        key: const ValueKey('importing'),
        style: typography.titleMedium.onSurface,
      ),
      LanReceiveDone(:final report) => Column(
        key: const ValueKey('done'),
        children: [
          Text(
            context.l10n.sync.lanDone,
            style: typography.titleMedium.onSurface,
          ),
          const SizedBox(height: 6),
          Text(
            _summary(report),
            textAlign: .center,
            // 有失败就不能和「全部收完」长一个样：接收方磁盘不足时日记先落库、
            // 媒体半途 ENOSPC，用户会据此抹掉旧机。
            style: report.failed > 0 || report.cancelled
                ? typography.bodyMedium.error
                : typography.bodyMedium.onSurfaceVariant,
          ),
          const SizedBox(height: 4),
          Text(
            report.failed > 0 || report.cancelled
                ? context.l10n.sync.lanDonePartialHint
                : context.l10n.sync.lanDoneHint,
            style: report.failed > 0 || report.cancelled
                ? typography.bodySmall.error
                : typography.bodySmall.outline,
          ),
        ],
      ),
      LanReceiveFailed(:final message) => Column(
        key: const ValueKey('failed'),
        children: [
          Text(
            context.l10n.sync.lanFailed,
            style: typography.titleMedium.error,
          ),
          const SizedBox(height: 6),
          Text(message, textAlign: .center, style: typography.bodySmall.error),
          const SizedBox(height: 4),
          Text(
            context.l10n.sync.lanFailedHint,
            style: typography.bodySmall.outline,
          ),
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
          Text(
            context.l10n.sync.lanLocalAddress,
            style: typography.labelLarge.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          if (ips.isEmpty)
            Text(
              context.l10n.sync.lanNoWifi,
              style: typography.bodyMedium.error,
            )
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
            context.l10n.sync.lanReceiveHint,
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
      child: MInkWell(
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
