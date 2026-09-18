import 'dart:async';

import 'package:gap/gap.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/llm_provider_repository.dart';
import 'package:moodiary_assistant/src/presentation/assistant_tool_ui.dart';
import 'package:moodiary_assistant/src/presentation/permission_mode_sheet.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:mui/mui.dart';

class AssistantSettingPage extends StatelessWidget {
  const AssistantSettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.assistant.settingTitle)),
      body: Padding(
        padding: const .symmetric(horizontal: 8.0),
        child: CustomScrollView(
          slivers: [
            const _ProviderSection(),
            const _PersonalSection(),
            const _ToolSection(),
            SliverGap(context.safeBottom),
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
    return MSliverSettingGroup(
      title: context.l10n.assistant.modelProviderTitle,
      children: const [_ProviderEntryTile()],
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

  late final _repo = getIt<LlmProviderRepository>();

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
      title: l10n.assistant.modelProviderTitle,
      subtitle: subtitle,
      leading: const Icon(LucideIcons.cloud),
      trailing: const Icon(LucideIcons.chevronRight),
      onTap: () => const AssistantProvidersRoute().push(context),
    );
  }
}

class _PersonalSection extends StatefulWidget {
  const _PersonalSection();

  @override
  State<_PersonalSection> createState() => _PersonalSectionState();
}

class _PersonalSectionState extends State<_PersonalSection> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final notes = (MoodiaryKVs.assistantUserNotes.get() ?? '').trim();
    final memoryOn = MoodiaryKVs.assistantMemoryEnabled.get() ?? false;
    return MSliverSettingGroup(
      title: l10n.assistant.personalSectionTitle,
      children: [
        SettingListTile(
          title: l10n.assistant.notesTitle,
          subtitle: notes.isEmpty
              ? l10n.assistant.notesEmpty
              : notes.split('\n').first,
          leading: const Icon(LucideIcons.notebookPen),
          trailing: const Icon(LucideIcons.chevronRight),
          onTap: () async {
            await const AssistantNotesRoute().push(context);
            if (mounted) setState(() {});
          },
        ),
        SettingListTile(
          title: l10n.assistant.memoryTitle,
          subtitle: l10n.assistant.memoryTileSubtitle,
          leading: const Icon(LucideIcons.brain),
          trailing: Switch(
            value: memoryOn,
            onChanged: (v) {
              MoodiaryKVs.assistantMemoryEnabled.set(v);
              setState(() {});
            },
          ),
          onTap: memoryOn
              ? () => const AssistantMemoriesRoute().push(context)
              : null,
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
  AssistantPermissionMode get _mode =>
      AssistantPermissionMode.fromId(MoodiaryKVs.assistantPermissionMode.get());

  Future<void> _pickMode() async {
    final mode = await showPermissionModePicker(context, selected: _mode);
    if (mode == null) return;
    MoodiaryKVs.assistantPermissionMode.set(mode.id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SliverMainAxisGroup(
      slivers: [
        MSliverSettingGroup(
          title: l10n.assistant.tool,
          children: [
            SettingListTile(
              title: l10n.assistant.permissionTitle,
              subtitle: permissionModeLabel(l10n, _mode),
              leading: const Icon(LucideIcons.shieldCheck),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: _pickMode,
            ),
            for (final tool in AssistantTool.values) _toolTile(context, tool),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const .fromLTRB(16, 8, 16, 0),
            child: Text(
              l10n.assistant.toolSectionNote,
              style: context.theme.typography.bodySmall.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _toolTile(BuildContext context, AssistantTool tool) {
    final display = assistantToolDisplay(context, tool);
    return SettingListTile(
      leading: Icon(display.icon),
      title: display.title,
      subtitle: display.description,
    );
  }
}
