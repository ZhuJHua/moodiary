import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_assistant/src/data/agent_preset_resolver.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/presentation/assistant_tool_ui.dart';
import 'package:moodiary_assistant/src/routes.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:mui/mui.dart';

class AssistantSettingPage extends ConsumerWidget {
  const AssistantSettingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.assistant.settingTitle)),
      body: ListView(
        padding: const .symmetric(horizontal: 8, vertical: 8),
        children: const [
          _Note(),
          SizedBox(height: 4),
          _ProviderSection(),
          SizedBox(height: 4),
          _PresetSection(),
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
    final scheme = context.theme.colors;
    return Card.filled(
      color: scheme.surfaceContainerHighest,
      margin: const .symmetric(horizontal: 8),
      child: Padding(
        padding: const .all(12),
        child: Row(
          children: [
            Icon(LucideIcons.bot, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.assistant.settingNote,
                style: context.theme.typography.bodySmall.onSurfaceVariant,
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
    final scheme = context.theme.colors;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        SettingTitleTile(title: context.l10n.assistant.modelProviderTitle),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: .zero,
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

  LlmProviderRepository get _repo => .get();

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
        ? l10n.assistant.providerEntryLoading
        : active == null
        ? l10n.assistant.providerEntryEmpty
        : '${active.name} · ${active.defaultModel}';
    return SettingListTile(
      isFirst: true,
      isLast: true,
      title: l10n.assistant.modelProviderTitle,
      subtitle: subtitle,
      leading: const Icon(LucideIcons.cloud),
      trailing: const Icon(LucideIcons.chevronRight),
      onTap: () => const AssistantProvidersRoute().push(context),
    );
  }
}

class _PresetSection extends StatefulWidget {
  const _PresetSection();

  @override
  State<_PresetSection> createState() => _PresetSectionState();
}

class _PresetSectionState extends State<_PresetSection> {
  /// 当前默认预设的显示名；null = 内置（用 l10n 名）。
  String? _defaultName;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = await AgentPresetResolver.defaultId();
    final preset = id == builtinAgentPresetId
        ? null
        : await AgentPresetRepository.get().get(id);
    if (mounted) {
      setState(() {
        _defaultName = preset?.name;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final l10n = context.l10n;
    final subtitle = !_loaded
        ? ''
        : (_defaultName ?? l10n.assistant.presetBuiltinName);
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        SettingTitleTile(title: l10n.assistant.presetSectionTitle),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: .zero,
          child: SettingListTile(
            isFirst: true,
            isLast: true,
            title: l10n.assistant.presetTileTitle,
            subtitle: subtitle,
            leading: const Icon(LucideIcons.venetianMask),
            trailing: const Icon(LucideIcons.chevronRight),
            onTap: () async {
              await const AssistantPresetsRoute().push(context);
              await _load();
            },
          ),
        ),
      ],
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
    final scheme = context.theme.colors;
    final l10n = context.l10n;
    const tools = AssistantTool.values;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        SettingTitleTile(title: l10n.assistant.tool),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: .zero,
          child: Column(
            children: [
              for (var i = 0; i < tools.length; i++)
                _toolTile(
                  context,
                  tools[i],
                  isFirst: i == 0,
                  isLast: i == tools.length - 1,
                ),
            ],
          ),
        ),
        Padding(
          padding: const .fromLTRB(16, 8, 16, 0),
          child: Text(
            l10n.assistant.toolSectionNote,
            style: context.theme.typography.bodySmall.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _toolTile(
    BuildContext context,
    AssistantTool tool, {
    required bool isFirst,
    required bool isLast,
  }) {
    final display = assistantToolDisplay(context, tool);
    return SettingListTile(
      isFirst: isFirst,
      isLast: isLast,
      leading: Icon(display.icon),
      title: display.title,
      subtitle: display.description,
    );
  }
}
