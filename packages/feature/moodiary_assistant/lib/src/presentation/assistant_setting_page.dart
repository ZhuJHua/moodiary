import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_assistant/src/presentation/assistant_tool_ui.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_assistant/src/routes.dart';

class AssistantSettingPage extends ConsumerWidget {
  const AssistantSettingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.assistantSettingTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        children: const [
          _Note(),
          SizedBox(height: 4),
          _ProviderSection(),
          SizedBox(height: 4),
          _ToolSection(),
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
            Icon(Icons.smart_toy_outlined, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.assistantSettingNote,
                style: context.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderSection extends StatelessWidget {
  const _ProviderSection();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingTitleTile(title: context.l10n.modelProviderTitle),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: EdgeInsets.zero,
          child: const _ProviderEntryTile(),
        ),
      ],
    );
  }
}

class _ProviderEntryTile extends StatefulWidget {
  const _ProviderEntryTile();

  @override
  State<_ProviderEntryTile> createState() => _ProviderEntryTileState();
}

class _ProviderEntryTileState extends State<_ProviderEntryTile> {
  LlmProvider? _active;
  bool _loaded = false;
  StreamSubscription<void>? _sub;
  late final VoidCallback _activeListener;
  late final ValueNotifier<String> _activeNotifier;

  LlmProviderRepository get _repo => LlmProviderRepository.get();

  @override
  void initState() {
    super.initState();
    _activeNotifier = MoodiaryKVs.assistantActiveProviderId.getNotifier();
    _activeListener = _load;
    _activeNotifier.addListener(_activeListener);
    _sub = _repo.providerEvents.listen((_) => _load());
    _load();
  }

  @override
  void dispose() {
    _activeNotifier.removeListener(_activeListener);
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final active = await _repo.getActiveProvider();
    if (mounted) {
      setState(() {
        _active = active;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final active = _active;
    final subtitle = !_loaded
        ? l10n.assistantProviderEntryLoading
        : active == null
        ? l10n.assistantProviderEntryEmpty
        : '${active.name} · ${active.model}';
    return SettingListTile(
      isFirst: true,
      isLast: true,
      title: l10n.modelProviderTitle,
      subtitle: subtitle,
      leading: const Icon(Icons.cloud_rounded),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => const AssistantProvidersRoute().push(context),
    );
  }
}

class _ToolSection extends StatefulWidget {
  const _ToolSection();

  @override
  State<_ToolSection> createState() => _ToolSectionState();
}

class _ToolSectionState extends State<_ToolSection> {
  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final l10n = context.l10n;
    const tools = AssistantTool.values;
    final always =
        MoodiaryKVs.assistantAlwaysAllowedTools.get() ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingTitleTile(title: l10n.assistantSectionTool),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < tools.length; i++)
                _toolTile(
                  context,
                  tools[i],
                  isFirst: i == 0,
                  isLast: i == tools.length - 1,
                  alwaysAllowed: always.contains(tools[i].id),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            l10n.assistantToolSectionNote,
            style: context.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        if (always.isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _resetGrants,
              icon: const Icon(Icons.lock_reset_rounded),
              label: Text(l10n.assistantToolResetGrants),
            ),
          ),
      ],
    );
  }

  Future<void> _resetGrants() async {
    await MoodiaryKVs.assistantAlwaysAllowedTools.set(const []);
    if (!mounted) return;
    setState(() {});
    toast.success(message: context.l10n.assistantToolResetGrantsDone);
  }

  Widget _toolTile(
    BuildContext context,
    AssistantTool tool, {
    required bool isFirst,
    required bool isLast,
    required bool alwaysAllowed,
  }) {
    final scheme = context.colorScheme;
    final display = assistantToolDisplay(context, tool);
    final hasTrailing = alwaysAllowed || tool.dangerous;
    return SettingListTile(
      isFirst: isFirst,
      isLast: isLast,
      leading: Icon(display.icon),
      title: display.title,
      subtitle: display.description,
      trailing: !hasTrailing
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (alwaysAllowed)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Tooltip(
                      message: context.l10n.assistantToolAlwaysAllowedHint,
                      child: Icon(
                        Icons.verified_user_rounded,
                        size: 18,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                if (tool.dangerous) const _DangerBadge(),
              ],
            ),
    );
  }
}

class _DangerBadge extends StatelessWidget {
  const _DangerBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        context.l10n.assistantToolDangerBadge,
        style: context.textTheme.labelSmall?.copyWith(
          color: scheme.onErrorContainer,
        ),
      ),
    );
  }
}
