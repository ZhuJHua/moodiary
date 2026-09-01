import 'package:moodiary_assistant/src/data/agent_preset_repository.dart';
import 'package:moodiary_assistant/src/data/agent_preset_resolver.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/presentation/agent_preset_sheet.dart';
import 'package:moodiary_assistant/src/routes.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:mui/mui.dart';

/// 助手预设管理：内置「Moodiary助手」（只读，可派生）+ 用户预设（可编辑 / 派生 /
/// 删除）。创建只有派生一条路（dsh 同款：copy is the only way），FAB = 从内置派生。
///
/// 「默认」标记只影响**新会话**的初始预设；已有会话钉的是自己创建时那份。
class AgentPresetListPage extends StatefulWidget {
  const AgentPresetListPage({super.key});

  @override
  State<AgentPresetListPage> createState() => _AgentPresetListPageState();
}

class _AgentPresetListPageState extends State<AgentPresetListPage> {
  List<AgentPreset> _presets = const [];
  String _defaultId = builtinAgentPresetId;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final presets = await AgentPresetRepository.get().getAll();
    final defaultId = await AgentPresetResolver.defaultId();
    if (!mounted) return;
    setState(() {
      _presets = presets;
      _defaultId = defaultId;
      _loaded = true;
    });
  }

  Future<void> _setDefault(String id) async {
    MoodiaryKVs.assistantAgentPresetId.set(id);
    setState(() => _defaultId = id);
  }

  Future<void> _derive(String? fromId) async {
    await AssistantPresetEditRoute(fromId: fromId).push(context);
    await _load();
  }

  Future<void> _edit(AgentPreset preset) async {
    await AssistantPresetEditRoute(id: preset.id).push(context);
    await _load();
  }

  Future<void> _delete(AgentPreset preset) async {
    final l10n = context.l10n;
    final confirmed = await MAlert.confirm(
      context,
      icon: LucideIcons.trash2,
      title: l10n.assistant.presetDeleteTitle,
      message: l10n.assistant.presetDeleteMessage(name: preset.name),
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    await AgentPresetRepository.get().delete(preset.id);
    // 删的是默认项 → 默认回落内置。
    if (_defaultId == preset.id) {
      MoodiaryKVs.assistantAgentPresetId.set(builtinAgentPresetId);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.assistant.presetPageTitle)),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.assistant.presetDerive,
        onPressed: () => _derive(null),
        child: const Icon(LucideIcons.plus),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const .fromLTRB(16, 8, 16, 96),
              children: [
                _PresetCard(
                  name: l10n.assistant.presetBuiltinName,
                  description: l10n.assistant.presetBuiltinDes,
                  builtin: true,
                  toolCount: null,
                  isDefault: _defaultId == builtinAgentPresetId,
                  onTap: () => showAgentPresetInfo(
                    context,
                    name: l10n.assistant.presetBuiltinName,
                    persona: defaultPersona,
                  ),
                  onSetDefault: _defaultId == builtinAgentPresetId
                      ? null
                      : () => _setDefault(builtinAgentPresetId),
                  onDerive: () => _derive(null),
                  onDelete: null,
                ),
                for (final p in _presets)
                  _PresetCard(
                    name: p.name,
                    description: p.description,
                    builtin: false,
                    toolCount: p.tools?.length,
                    isDefault: _defaultId == p.id,
                    onTap: () => _edit(p),
                    onSetDefault: _defaultId == p.id
                        ? null
                        : () => _setDefault(p.id),
                    onDerive: () => _derive(p.id),
                    onDelete: () => _delete(p),
                  ),
              ],
            ),
    );
  }
}

enum _CardAction { setDefault, derive, delete }

class _PresetCard extends StatelessWidget {
  final String name;
  final String description;
  final bool builtin;

  /// 自定义了工具子集时的工具数；null = 全部（不显示标签）。
  final int? toolCount;
  final bool isDefault;
  final VoidCallback onTap;

  /// null = 已经是默认项，菜单里不再给这一项。
  final VoidCallback? onSetDefault;
  final VoidCallback onDerive;

  /// null = 内置预设，不可删。
  final VoidCallback? onDelete;

  const _PresetCard({
    required this.name,
    required this.description,
    required this.builtin,
    required this.toolCount,
    required this.isDefault,
    required this.onTap,
    required this.onSetDefault,
    required this.onDerive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    final l10n = context.l10n;
    return Padding(
      padding: const .only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: MuiRadius.md,
        clipBehavior: .antiAlias,
        child: MInkWell(
          onTap: onTap,
          child: Padding(
            padding: const .fromLTRB(16, 12, 4, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    mainAxisSize: .min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: .ellipsis,
                              style: typography.titleSmall.emphasized.onSurface,
                            ),
                          ),
                          if (builtin) ...[
                            const SizedBox(width: 6),
                            _Tag(text: l10n.assistant.presetBuiltinBadge),
                          ],
                          if (isDefault) ...[
                            const SizedBox(width: 6),
                            _Tag(
                              text: l10n.assistant.presetDefaultBadge,
                              emphasized: true,
                            ),
                          ],
                          if (toolCount case final count?) ...[
                            const SizedBox(width: 6),
                            _Tag(
                              text: l10n.assistant.presetToolCount(
                                count: count,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: .ellipsis,
                          style: typography.bodySmall.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
                ),
                MMenuButton<_CardAction>(
                  tooltip: l10n.common.more,
                  onSelected: (v) => switch (v) {
                    _CardAction.setDefault => onSetDefault?.call(),
                    _CardAction.derive => onDerive(),
                    _CardAction.delete => onDelete?.call(),
                  },
                  entries: [
                    if (onSetDefault != null)
                      MMenuEntry(
                        value: _CardAction.setDefault,
                        label: l10n.assistant.presetSetDefault,
                        icon: LucideIcons.circleCheck,
                      ),
                    MMenuEntry(
                      value: _CardAction.derive,
                      label: l10n.assistant.presetDerive,
                      icon: LucideIcons.copy,
                    ),
                    if (onDelete != null)
                      MMenuEntry(
                        value: _CardAction.delete,
                        label: l10n.common.delete,
                        icon: LucideIcons.trash2,
                        isDestructive: true,
                      ),
                  ],
                  child: Padding(
                    padding: const .all(12),
                    child: Icon(
                      LucideIcons.ellipsisVertical,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final bool emphasized;

  const _Tag({required this.text, this.emphasized = false});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Container(
      padding: const .symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: emphasized
            ? scheme.secondaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: .circular(6),
      ),
      child: Text(
        text,
        style: emphasized
            ? context.theme.typography.labelSmall.onSecondaryContainer
            : context.theme.typography.labelSmall.onSurfaceVariant,
      ),
    );
  }
}
