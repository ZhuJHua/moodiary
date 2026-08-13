import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_sync/src/data/lan/lan_discovery.dart';
import 'package:moodiary_sync/src/data/lan/lan_protocol.dart';
import 'package:moodiary_sync/src/data/lan/lan_sender.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/presentation/widget/lan_widgets.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:mui/mui.dart';

class LanSendPage extends StatefulWidget {
  const LanSendPage({super.key});

  @override
  State<LanSendPage> createState() => _LanSendPageState();
}

class _LanSendPageState extends State<LanSendPage> {
  late final TextEditingController _hostController = TextEditingController(
    text: MoodiaryKVs.lanSendTarget.get(),
  );
  final TextEditingController _pinController = TextEditingController();
  final LanBrowser _browser = LanBrowser();

  bool _running = false;
  LanSendProgress? _progress;
  String? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _browser.start();
    _hostController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _browser.stop();
    _hostController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  String _peerAddress(LanPeer peer) =>
      peer.port == lanDefaultPort ? peer.host : '${peer.host}:${peer.port}';

  void _pickPeer(LanPeer peer) {
    _hostController.text = _peerAddress(peer);
  }

  Future<void> _send() async {
    final target = _hostController.text.trim();
    final pin = _pinController.text.trim();
    if (target.isEmpty) {
      toast.info(message: l10n.sync.lanPickDevice);
      return;
    }
    if (pin.length != 6) {
      toast.info(message: l10n.sync.lanNeedPin);
      return;
    }
    final String host;
    int port = lanDefaultPort;
    final colonIdx = target.lastIndexOf(':');
    if (colonIdx > 0 && !target.contains('::')) {
      host = target.substring(0, colonIdx);
      final parsed = int.tryParse(target.substring(colonIdx + 1));
      if (parsed == null || parsed <= 0 || parsed > 65535) {
        toast.info(message: l10n.sync.lanBadAddress);
        return;
      }
      port = parsed;
    } else {
      host = target;
    }
    await MoodiaryKVs.lanSendTarget.set(target);

    setState(() {
      _running = true;
      _progress = null;
      _result = null;
      _error = null;
    });
    try {
      final result = await LanSender().send(
        host: host,
        port: port,
        pin: pin,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      setState(() => _result = result.describe());
    } on SyncException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
    padding: const .only(bottom: 10),
    child: Text(
      text,
      style: context.theme.typography.labelLarge.onSurfaceVariant,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.sync.lanSendTitle)),
      body: ListView(
        padding: const .fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            context.l10n.sync.lanSendIntro,
            style: context.theme.typography.bodySmall.onSurfaceVariant,
          ),
          const SizedBox(height: 20),
          _sectionLabel(context, context.l10n.sync.lanNearbyDevices),
          ValueListenableBuilder(
            valueListenable: _browser.peers,
            builder: (context, peers, _) => _PeerList(
              peers: peers,
              selectedAddress: _hostController.text.trim(),
              enabled: !_running,
              addressOf: _peerAddress,
              onPick: _pickPeer,
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel(context, context.l10n.sync.lanReceiverAddress),
          TextField(
            controller: _hostController,
            enabled: !_running,
            keyboardType: .url,
            decoration: InputDecoration(
              hintText: context.l10n.sync.lanAddressHint,
              prefixIcon: const Icon(LucideIcons.network),
              filled: true,
              fillColor: scheme.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: .circular(14),
                borderSide: .none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: .circular(14),
                borderSide: BorderSide(color: scheme.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel(context, context.l10n.sync.lanPin),
          LanPinInput(controller: _pinController, enabled: !_running),
          const SizedBox(height: 6),
          Center(
            child: Text(
              context.l10n.sync.lanPinHint,
              style: context.theme.typography.bodySmall.outline,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _running ? null : _send,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: .circular(16)),
              ),
              icon: const Icon(LucideIcons.send),
              label: Text(context.l10n.sync.lanSendAction),
            ),
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _running
                ? _ProgressCard(progress: _progress)
                : _result != null
                ? _ResultCard.success(_result!)
                : _error != null
                ? _ResultCard.error(_error!)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _PeerList extends StatelessWidget {
  final List<LanPeer> peers;
  final String selectedAddress;
  final bool enabled;
  final String Function(LanPeer) addressOf;
  final void Function(LanPeer) onPick;

  const _PeerList({
    required this.peers,
    required this.selectedAddress,
    required this.enabled,
    required this.addressOf,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    if (peers.isEmpty) {
      return Container(
        padding: const .symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: .circular(16),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.sync.lanSearching,
                style: context.theme.typography.bodySmall.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final (index, peer) in peers.indexed) ...[
          if (index > 0) const SizedBox(height: 8),
          _PeerTile(
            peer: peer,
            address: addressOf(peer),
            selected: addressOf(peer) == selectedAddress,
            enabled: enabled,
            onPick: onPick,
          ),
        ],
      ],
    );
  }
}

class _PeerTile extends StatelessWidget {
  final LanPeer peer;
  final String address;
  final bool selected;
  final bool enabled;
  final void Function(LanPeer) onPick;

  const _PeerTile({
    required this.peer,
    required this.address,
    required this.selected,
    required this.enabled,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
        borderRadius: .circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: .circular(16),
        child: InkWell(
          borderRadius: .circular(16),
          onTap: enabled ? () => onPick(peer) : null,
          child: Padding(
            padding: const .all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: .circle,
                    color: selected
                        ? scheme.primary
                        : scheme.surfaceContainerHigh,
                  ),
                  child: Icon(
                    LucideIcons.smartphone,
                    size: 20,
                    color: selected
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        peer.name,
                        maxLines: 1,
                        overflow: .ellipsis,
                        style: selected
                            ? typography.titleSmall.onPrimaryContainer
                            : typography.titleSmall.onSurface,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        address,
                        style:
                            (selected
                                    ? typography.bodySmall.onPrimaryContainer
                                    : typography.bodySmall.onSurfaceVariant)
                                .copyWith(fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(
                    LucideIcons.circleCheck,
                    color: scheme.onPrimaryContainer,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final LanSendProgress? progress;

  const _ProgressCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    final phase = progress?.phase ?? .connecting;
    final label = switch (phase) {
      .connecting => context.l10n.sync.lanConnecting,
      .packing => context.l10n.sync.lanPacking,
      .uploading => context.l10n.sync.lanUploading,
      .applying => context.l10n.sync.lanApplying,
    };
    final sent = progress?.sent ?? 0;
    final total = progress?.total;
    return Container(
      key: const ValueKey('progress'),
      padding: const .all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: .circular(16),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(label, style: typography.titleSmall.onSurface),
              const Spacer(),
              if (phase == .uploading && total != null && total > 0)
                Text(
                  '${(sent / total * 100).clamp(0, 100).toStringAsFixed(0)}%',
                  style: typography.titleSmall.primary.copyWith(
                    fontFeatures: const [.tabularFigures()],
                  ),
                ),
            ],
          ),
          if (phase == .uploading) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (total != null && total > 0) ? sent / total : null,
              minHeight: 8,
              borderRadius: .circular(999),
            ),
            const SizedBox(height: 8),
            Text(
              total != null
                  ? '${lanFmtBytes(sent)} / ${lanFmtBytes(total)}'
                  : lanFmtBytes(sent),
              style: typography.bodySmall.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String message;
  final bool success;

  const _ResultCard.success(this.message) : success = true;

  const _ResultCard.error(this.message) : success = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    // 成功走 primary、失败走 error —— 灰度档下没有绿色可用于「成功」。
    final background = success
        ? scheme.primaryContainer
        : scheme.errorContainer;
    final style = success
        ? context.theme.typography.bodyMedium.onPrimaryContainer
        : context.theme.typography.bodyMedium.onErrorContainer;
    return Container(
      key: ValueKey(success ? 'result' : 'error'),
      padding: const .all(16),
      decoration: BoxDecoration(color: background, borderRadius: .circular(16)),
      child: Row(
        crossAxisAlignment: .start,
        children: [
          Icon(
            success ? LucideIcons.circleCheck : LucideIcons.circleAlert,
            color: style.color,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: style)),
        ],
      ),
    );
  }
}
