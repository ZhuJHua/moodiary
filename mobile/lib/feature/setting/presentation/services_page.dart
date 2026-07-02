import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_scan/moodiary_scan.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary/app/router/router.dart';

class ServicesPage extends ConsumerWidget {
  const ServicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('第三方服务')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        children: const [
          _Note(),
          SizedBox(height: 4),
          _AiSection(),
          SizedBox(height: 4),
          _QweatherSection(),
          SizedBox(height: 4),
          _TiandituSection(),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Card.filled(
      color: scheme.surfaceContainerHighest,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.hub_outlined, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '在此填入您自有的第三方服务凭证，启用 AI 助手、天气与地图等能力。'
                '所有凭证仅保存在本机；API Key 可生成时效二维码在设备间转移。',
                style: context.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiSection extends StatelessWidget {
  const _AiSection();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SettingTitleTile(title: 'AI 助手'),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: EdgeInsets.zero,
          child: ValueListenableBuilder<String>(
            valueListenable: MoodiaryKVs.assistantActiveProviderId.getNotifier(),
            builder: (context, _, _) => const _AiSummaryTile(),
          ),
        ),
      ],
    );
  }
}

class _AiSummaryTile extends StatefulWidget {
  const _AiSummaryTile();

  @override
  State<_AiSummaryTile> createState() => _AiSummaryTileState();
}

class _AiSummaryTileState extends State<_AiSummaryTile> {
  LlmProvider? _active;
  bool _keyConfigured = false;
  bool _loaded = false;
  StreamSubscription<void>? _sub;

  LlmProviderRepository get _repo => LlmProviderRepository.get();

  @override
  void initState() {
    super.initState();
    _sub = _repo.providerEvents.listen((_) => _load());
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final active = await _repo.getActiveProvider();
    final key = active == null ? null : await _repo.getKey(active.id);
    if (!mounted) return;
    setState(() {
      _active = active;
      _keyConfigured = key != null && key.isNotEmpty;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    final subtitle = !_loaded
        ? '加载中…'
        : active == null
        ? '未配置模型供应商'
        : '${active.name} · ${active.model} · '
              '${_keyConfigured ? 'Key 已配置' : 'Key 未配置'}';
    return SettingListTile(
      isFirst: true,
      isLast: true,
      title: 'AI 助手配置',
      subtitle: subtitle,
      leading: const Icon(Icons.smart_toy_rounded),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () async {
        await const AssistantSettingRoute().push(context);
        await _load();
      },
    );
  }
}

class _QweatherSection extends ConsumerWidget {
  const _QweatherSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SettingTitleTile(title: '和风天气'),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: EdgeInsets.zero,
          child: const Column(
            children: [
              _KvQrTile(
                kv: MoodiaryKVs.qweatherKey,
                title: 'API Key',
                leading: Icon(Icons.vpn_key_rounded),
                prefix: 'qweatherKey:',
                isFirst: true,
              ),
              _KvQrTile(
                kv: MoodiaryKVs.qweatherApiHost,
                title: 'API Host',
                subtitleWhenEmpty: 'devapi.qweather.com 或自定义',
                leading: Icon(Icons.dns_rounded),
                prefix: 'qweatherHost:',
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TiandituSection extends ConsumerWidget {
  const _TiandituSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SettingTitleTile(title: '天地图'),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: EdgeInsets.zero,
          child: const Column(
            children: [
              _KvQrTile(
                kv: MoodiaryKVs.tiandituKey,
                title: 'API Key',
                leading: Icon(Icons.map_rounded),
                prefix: 'tiandituKey:',
                isFirst: true,
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KvQrTile extends StatelessWidget {
  final MoodiaryKVs<String> kv;
  final String title;
  final Widget? leading;
  final String? prefix;
  final String? subtitleWhenEmpty;
  final bool isFirst;
  final bool isLast;

  const _KvQrTile({
    required this.kv,
    required this.title,
    this.leading,
    this.prefix,
    this.subtitleWhenEmpty,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: kv.getNotifierOr(''),
      builder: (context, value, _) {
        return QrInputTile(
          isFirst: isFirst,
          isLast: isLast,
          title: title,
          leading: leading,
          prefix: prefix,
          value: value,
          subtitle: value.isEmpty ? (subtitleWhenEmpty ?? '未配置') : '已配置',
          onValue: (v) async {
            await kv.set(v);
            toast.success(message: '已保存');
          },
        );
      },
    );
  }
}
