import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/presentation/assistant_tool_ui.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:mui/mui.dart';

/// 选择结果。[name] 为 null 表示内置预设（显示名走 l10n）。
typedef AgentPresetChoice = ({String id, String? name});

/// 空白会话换预设的底部弹窗：内置「Moodiary助手」+ 用户预设，点选即回。
/// 返回 null 表示取消。
Future<AgentPresetChoice?> showAgentPresetPicker(
  BuildContext context, {
  required String selectedId,
}) async {
  final presets = await AgentPresetRepository.get().getAll();
  if (!context.mounted) return null;
  return MSheet.show<AgentPresetChoice>(
    context,
    builder: (sheetContext) =>
        _PresetPickerBody(presets: presets, selectedId: selectedId),
  );
}

/// 已钉会话的只读预览：预设名 + 人格全文 + 工具子集（来自会话快照，预设被删也
/// 照常可看）。[tools] null = 全部工具。
void showAgentPresetInfo(
  BuildContext context, {
  required String name,
  required String persona,
  List<String>? tools,
}) {
  MSheet.show<void>(
    context,
    builder: (sheetContext) {
      final l10n = sheetContext.l10n;
      final typography = sheetContext.theme.typography;
      return MSheetScaffold<void>(
        title: name,
        subtitle: l10n.assistant.presetInfoSubtitle,
        icon: LucideIcons.venetianMask,
        actions: [MAction(label: l10n.common.ok, isPrimary: true)],
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.5,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: .start,
              mainAxisSize: .min,
              children: [
                Text(
                  l10n.assistant.tool,
                  style: typography.labelSmall.onSurfaceVariant,
                ),
                const SizedBox(height: 4),
                _ToolTags(tools: tools),
                const SizedBox(height: 12),
                Text(
                  l10n.assistant.presetPersonaLabel,
                  style: typography.labelSmall.onSurfaceVariant,
                ),
                const SizedBox(height: 2),
                Text(persona, style: typography.bodySmall.onSurface),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// 工具子集的只读展示：null = 全部；未知 id（工具集随版本变化）静默跳过。
class _ToolTags extends StatelessWidget {
  final List<String>? tools;

  const _ToolTags({required this.tools});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typography = context.theme.typography;
    final tools = this.tools;
    if (tools == null) {
      return Text(
        l10n.assistant.presetToolsAll,
        style: typography.bodySmall.onSurface,
      );
    }
    final names = [
      for (final tool in AssistantTool.values)
        if (tools.contains(tool.id)) assistantToolDisplay(context, tool).title,
    ];
    if (names.isEmpty) {
      return Text(
        l10n.assistant.presetToolsNone,
        style: typography.bodySmall.onSurface,
      );
    }
    final scheme = context.theme.colors;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final name in names)
          Container(
            padding: const .symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: .circular(6),
            ),
            child: Text(name, style: typography.labelSmall.onSurfaceVariant),
          ),
      ],
    );
  }
}

class _PresetPickerBody extends StatelessWidget {
  final List<AgentPreset> presets;
  final String selectedId;

  const _PresetPickerBody({required this.presets, required this.selectedId});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MSheetScaffold<AgentPresetChoice>(
      title: l10n.assistant.presetPickerTitle,
      icon: LucideIcons.venetianMask,
      actions: [MAction(label: l10n.common.cancel)],
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.5,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            _PresetTile(
              name: l10n.assistant.presetBuiltinName,
              description: l10n.assistant.presetBuiltinDes,
              builtin: true,
              toolCount: null,
              selected: selectedId == builtinAgentPresetId,
              onTap: () =>
                  Navigator.of(context)
                      .pop((id: builtinAgentPresetId, name: null)),
            ),
            for (final p in presets)
              _PresetTile(
                name: p.name,
                description: p.description,
                builtin: false,
                toolCount: p.tools?.length,
                selected: selectedId == p.id,
                onTap: () =>
                    Navigator.of(context).pop((id: p.id, name: p.name)),
              ),
          ],
        ),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  final String name;
  final String description;
  final bool builtin;

  /// 自定义了工具子集时的工具数；null = 全部（不显示标签）。
  final int? toolCount;
  final bool selected;
  final VoidCallback onTap;

  const _PresetTile({
    required this.name,
    required this.description,
    required this.builtin,
    required this.toolCount,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    final l10n = context.l10n;
    return Padding(
      padding: const .only(bottom: 6),
      child: Material(
        color: selected
            ? scheme.secondaryContainer
            : scheme.surfaceContainerLow,
        borderRadius: MuiRadius.md,
        clipBehavior: .antiAlias,
        child: MInkWell(
          onTap: onTap,
          child: Padding(
            padding: const .symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: .start,
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
                              style: selected
                                  ? typography
                                        .titleSmall
                                        .emphasized
                                        .onSecondaryContainer
                                  : typography.titleSmall.onSurface,
                            ),
                          ),
                          if (builtin) ...[
                            const SizedBox(width: 6),
                            Text(
                              l10n.assistant.presetBuiltinBadge,
                              style: typography.labelSmall.onSurfaceVariant,
                            ),
                          ],
                          if (toolCount case final count?) ...[
                            const SizedBox(width: 6),
                            Text(
                              l10n.assistant.presetToolCount(count: count),
                              style: typography.labelSmall.onSurfaceVariant,
                            ),
                          ],
                        ],
                      ),
                      if (description.isNotEmpty)
                        Text(
                          description,
                          maxLines: 2,
                          overflow: .ellipsis,
                          style: typography.labelSmall.onSurfaceVariant,
                        ),
                    ],
                  ),
                ),
                if (selected)
                  Padding(
                    padding: const .only(left: 8, top: 2),
                    child: Icon(
                      LucideIcons.circleCheck,
                      size: 18,
                      color: scheme.onSecondaryContainer,
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
