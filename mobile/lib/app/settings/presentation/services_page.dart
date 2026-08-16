import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_assistant/moodiary_assistant.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
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
              _SecretKvTile(
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
              _SecretKvTile(
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
  final bool isLast;

  const _KvTile({
    required this.kv,
    required this.title,
    this.leading,
    this.subtitleWhenEmpty,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: kv.getNotifierOr(''),
      builder: (context, value, _) {
        return SettingInputTile(
          isLast: isLast,
          title: title,
          leading: leading,
          value: value,
          subtitle: value.isEmpty
              ? (subtitleWhenEmpty ?? context.l10n.common.notConfigured)
              : context.l10n.common.configured,
          onValue: (v) async {
            kv.set(v);
            toast.success(message: l10n.app.servicesSaved);
          },
        );
      },
    );
  }
}

/// 同 [_KvTile]，但值在 SecureKV 里：读是异步的、也没有 [KVNotifier]，
/// 所以走 `secretKvProvider` 并在写完 invalidate。
class _SecretKvTile extends ConsumerWidget {
  final MoodiarySecureKVs kv;
  final String title;
  final Widget? leading;
  final bool isFirst;
  final bool isLast;

  const _SecretKvTile({
    required this.kv,
    required this.title,
    this.leading,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 钥匙串读的这一小段空窗按「未配置」渲染，与真的没配一致，不闪骨架。
    final value = ref.watch(secretKvProvider(kv)).value ?? '';
    return SettingInputTile(
      isFirst: isFirst,
      isLast: isLast,
      title: title,
      leading: leading,
      value: value,
      subtitle: value.isEmpty
          ? context.l10n.common.notConfigured
          : context.l10n.common.configured,
      onValue: (v) async {
        // 写钥匙串会抛（设备锁定 / Keystore 故障）；吞掉的话磁贴还显示旧值，
        // 看起来像存成功了。ref 在 await 之后用，先确认还挂着。
        try {
          await kv.set(v);
        } catch (e, s) {
          logger.e('保存 $kv 失败', error: e, stackTrace: s);
          toast.error(message: l10n.app.servicesSaveFailed);
          return;
        }
        if (!context.mounted) return;
        ref.invalidate(secretKvProvider(kv));
        toast.success(message: l10n.app.servicesSaved);
      },
    );
  }
}
