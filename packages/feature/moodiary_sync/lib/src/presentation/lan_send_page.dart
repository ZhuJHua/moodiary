import 'package:flutter/material.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_sync/src/data/lan/lan_discovery.dart';
import 'package:moodiary_sync/src/data/lan/lan_protocol.dart';
import 'package:moodiary_sync/src/data/lan/lan_sender.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/presentation/widget/lan_widgets.dart';

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
      toast.info(message: '请先选择接收设备');
      return;
    }
    if (pin.length != 6) {
      toast.info(message: '请输入 6 位配对码');
      return;
    }
    final String host;
    int port = lanDefaultPort;
    final colonIdx = target.lastIndexOf(':');
    if (colonIdx > 0 && !target.contains('::')) {
      host = target.substring(0, colonIdx);
      final parsed = int.tryParse(target.substring(colonIdx + 1));
      if (parsed == null || parsed <= 0 || parsed > 65535) {
        toast.info(message: '地址格式不正确');
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
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: context.textTheme.labelLarge?.copyWith(
        color: context.colorScheme.onSurfaceVariant,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('局域网发送')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            '只发送对方缺少的内容，按最后修改时间自动合并，重复发送不会产生重复数据。',
            style: context.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel(context, '附近的设备'),
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
          _sectionLabel(context, '接收方地址'),
          TextField(
            controller: _hostController,
            enabled: !_running,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: '选择上方设备后自动填写',
              prefixIcon: const Icon(LucideIcons.network),
              filled: true,
              fillColor: scheme.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: scheme.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel(context, '配对码'),
          LanPinInput(controller: _pinController, enabled: !_running),
          const SizedBox(height: 6),
          Center(
            child: Text(
              '输入接收页显示的 6 位数字',
              style: context.textTheme.bodySmall?.copyWith(
                color: scheme.outline,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _running ? null : _send,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(LucideIcons.send),
              label: const Text('发送'),
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
    final scheme = context.colorScheme;
    if (peers.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
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
                '正在搜索，请在接收设备上打开「接收」页',
                style: context.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
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
    final scheme = context.colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? () => onPick(peer) : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        peer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.titleSmall?.copyWith(
                          color: selected ? scheme.onPrimaryContainer : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        address,
                        style: context.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: selected
                              ? scheme.onPrimaryContainer.withValues(alpha: .7)
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(LucideIcons.circleCheck, color: scheme.primary),
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
    final scheme = context.colorScheme;
    final phase = progress?.phase ?? LanSendPhase.connecting;
    final label = switch (phase) {
      LanSendPhase.connecting => '正在连接…',
      LanSendPhase.packing => '正在准备数据…',
      LanSendPhase.uploading => '正在发送',
      LanSendPhase.applying => '等待对方保存…',
    };
    final sent = progress?.sent ?? 0;
    final total = progress?.total;
    return Container(
      key: const ValueKey('progress'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(label, style: context.textTheme.titleSmall),
              const Spacer(),
              if (phase == LanSendPhase.uploading && total != null && total > 0)
                Text(
                  '${(sent / total * 100).clamp(0, 100).toStringAsFixed(0)}%',
                  style: context.textTheme.titleSmall?.copyWith(
                    color: scheme.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          if (phase == LanSendPhase.uploading) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (total != null && total > 0) ? sent / total : null,
              minHeight: 8,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 8),
            Text(
              total != null
                  ? '${lanFmtBytes(sent)} / ${lanFmtBytes(total)}'
                  : lanFmtBytes(sent),
              style: context.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
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
    final scheme = context.colorScheme;
    final background = success
        ? scheme.secondaryContainer
        : scheme.errorContainer;
    final foreground = success
        ? scheme.onSecondaryContainer
        : scheme.onErrorContainer;
    return Container(
      key: ValueKey(success ? 'result' : 'error'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            success ? LucideIcons.circleCheck : LucideIcons.circleAlert,
            color: foreground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: context.textTheme.bodyMedium?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
