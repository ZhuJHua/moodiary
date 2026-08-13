import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_assistant/moodiary_assistant.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:mui/mui.dart';

class ServicesPage extends ConsumerWidget {
  const ServicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.app.services)),
      body: ListView(
        padding: const .symmetric(horizontal: 8, vertical: 8),
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
    final scheme = context.theme.colors;
    return Card.filled(
      color: scheme.surfaceContainerHighest,
      margin: const .symmetric(horizontal: 8),
      child: Padding(
        padding: const .all(12),
        child: Row(
          children: [
            Icon(LucideIcons.waypoints, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.app.servicesIntro,
                style: context.theme.typography.bodySmall.onSurfaceVariant,
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
    final scheme = context.theme.colors;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        SettingTitleTile(title: context.l10n.app.servicesAssistant),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: .zero,
          child: ValueListenableBuilder<String>(
            valueListenable: MoodiaryKVs.assistantActiveProviderId
                .getNotifier(),
            builder: (context, _, _) => const AssistantSummaryTile(),
          ),
        ),
      ],
    );
  }
}

class _QweatherSection extends ConsumerWidget {
  const _QweatherSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.theme.colors;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        SettingTitleTile(title: context.l10n.app.servicesQweather),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: .zero,
          child: Column(
            children: [
              _KvTile(
                kv: .qweatherKey,
                title: 'API Key',
                leading: Icon(LucideIcons.key, color: scheme.onSurfaceVariant),
                isFirst: true,
              ),
              _KvTile(
                kv: .qweatherApiHost,
                title: 'API Host',
                subtitleWhenEmpty: context.l10n.app.servicesQweatherHostHint,
                leading: Icon(
                  LucideIcons.server,
                  color: scheme.onSurfaceVariant,
                ),
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
    final scheme = context.theme.colors;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        SettingTitleTile(title: context.l10n.app.servicesTianditu),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: .zero,
          child: Column(
            children: [
              _KvTile(
                kv: .tiandituKey,
                title: 'API Key',
                leading: Icon(LucideIcons.map, color: scheme.onSurfaceVariant),
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

class _KvTile extends StatelessWidget {
  final MoodiaryKVs<String> kv;
  final String title;
  final Widget? leading;
  final String? subtitleWhenEmpty;
  final bool isFirst;
  final bool isLast;

  const _KvTile({
    required this.kv,
    required this.title,
    this.leading,
    this.subtitleWhenEmpty,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: kv.getNotifierOr(''),
      builder: (context, value, _) {
        return SettingInputTile(
          isFirst: isFirst,
          isLast: isLast,
          title: title,
          leading: leading,
          value: value,
          subtitle: value.isEmpty
              ? (subtitleWhenEmpty ?? context.l10n.common.notConfigured)
              : context.l10n.common.configured,
          onValue: (v) async {
            await kv.set(v);
            toast.success(message: l10n.app.servicesSaved);
          },
        );
      },
    );
  }
}
