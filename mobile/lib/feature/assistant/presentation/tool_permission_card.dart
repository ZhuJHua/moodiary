import 'package:flutter/material.dart';
import 'package:genui/genui.dart' as genui;
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary/core/values/assistant.dart';
import 'package:moodiary/feature/assistant/application/tool_permission_coordinator.dart';
import 'package:moodiary/feature/assistant/presentation/assistant_tool_ui.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';

/// 助手专用 GenUI Catalog：只注册自定义组件，不复用 genui 内置目录。
final genui.Catalog assistantGenUiCatalog = genui.Catalog([
  _toolPermissionCard,
], catalogId: assistantGenUiCatalogId);

/// 把卡片 surface 内的用户动作转给 [onAction]（本地消化，不上报 AI 服务）。
class ToolPermissionActionDelegate implements genui.ActionDelegate {
  final void Function(String surfaceId, String actionName) onAction;

  const ToolPermissionActionDelegate(this.onAction);

  @override
  bool handleEvent(
    BuildContext context,
    genui.UiEvent event,
    genui.SurfaceContext genUiContext,
    Widget Function(
      genui.SurfaceDefinition,
      genui.Catalog,
      String,
      genui.DataContext,
    )
    buildWidget,
  ) {
    // UiEvent 是 extension type，运行时无法区分子类，按字段判别。
    final name = event.toMap()['name'];
    if (name is! String) return false;
    onAction(genUiContext.surfaceId, name);
    return true;
  }
}

final genui.CatalogItem _toolPermissionCard = genui.CatalogItem(
  name: toolPermissionCardComponent,
  dataSchema: S.object(
    description:
        'A Material 3 card that asks the user to approve an assistant tool '
        'call, then shows the resolved decision in place.',
    properties: {
      'tool': S.string(
        description: 'The id of the assistant tool requesting permission.',
        enumValues: [for (final tool in AssistantTool.values) tool.id],
      ),
      'status': genui.A2uiSchemas.stringReference(
        description:
            'Card status, bound to $toolPermissionStatusPath in the data '
            'model: pending | allowedOnce | allowedAlways | denied | canceled.',
      ),
    },
    required: ['tool', 'status'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, Object?>;
    // 消息由本地构造，id 必然合法；万一不合法由 Surface 兜底为 FallbackWidget。
    final tool = AssistantTool.values.firstWhere((t) => t.id == data['tool']);
    return genui.BoundString(
      dataContext: itemContext.dataContext,
      value: data['status'],
      builder: (context, statusId) => _ToolPermissionCardView(
        tool: tool,
        status: ToolPermissionStatus.fromId(statusId),
        onAction: (name) => itemContext.dispatchEvent(
          genui.UserActionEvent(name: name, sourceComponentId: itemContext.id),
        ),
      ),
    );
  },
);

class _ToolPermissionCardView extends StatelessWidget {
  final AssistantTool tool;

  final ToolPermissionStatus status;

  final ValueChanged<String> onAction;

  const _ToolPermissionCardView({
    required this.tool,
    required this.status,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final l10n = context.l10n;
    final display = assistantToolDisplay(context, tool);
    final dangerous = tool.dangerous;
    final pending = status == ToolPermissionStatus.pending;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: dangerous
                        ? scheme.errorContainer
                        : scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    display.icon,
                    size: 22,
                    color: dangerous
                        ? scheme.onErrorContainer
                        : scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(display.title, style: context.textTheme.titleMedium),
                      Text(
                        l10n.assistantToolPermissionTitle,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              display.description,
              style: context.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (dangerous && pending) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.report_gmailerrorred_rounded,
                      size: 18,
                      color: scheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.assistantToolPermissionDangerNote,
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.centerRight,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: pending
                    ? _PendingActions(
                        key: const ValueKey('pending'),
                        dangerous: dangerous,
                        onAction: onAction,
                      )
                    : Align(
                        key: ValueKey(status),
                        alignment: Alignment.centerRight,
                        child: _DecisionBadge(status: status),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingActions extends StatelessWidget {
  final bool dangerous;

  final ValueChanged<String> onAction;

  const _PendingActions({
    super.key,
    required this.dangerous,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final l10n = context.l10n;
    return OverflowBar(
      alignment: MainAxisAlignment.end,
      overflowAlignment: OverflowBarAlignment.end,
      spacing: 8,
      overflowSpacing: 4,
      children: [
        TextButton(
          onPressed: () => onAction(toolPermissionActionDeny),
          child: Text(l10n.assistantToolDeny),
        ),
        TextButton(
          onPressed: () => onAction(toolPermissionActionAllowAlways),
          style: dangerous
              ? TextButton.styleFrom(foregroundColor: scheme.error)
              : null,
          child: Text(l10n.assistantToolAllowAlways),
        ),
        FilledButton(
          onPressed: () => onAction(toolPermissionActionAllowOnce),
          child: Text(l10n.assistantToolAllowOnce),
        ),
      ],
    );
  }
}

/// 结果态徽章：按钮区被替换为带底色的决定说明，卡片本体保留。
class _DecisionBadge extends StatelessWidget {
  final ToolPermissionStatus status;

  const _DecisionBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final l10n = context.l10n;
    final (icon, background, foreground, label) = switch (status) {
      ToolPermissionStatus.allowedOnce => (
        Icons.check_circle_rounded,
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        l10n.assistantToolStatusAllowedOnce,
      ),
      ToolPermissionStatus.allowedAlways => (
        Icons.verified_rounded,
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        l10n.assistantToolAlwaysAllowedHint,
      ),
      ToolPermissionStatus.denied => (
        Icons.cancel_rounded,
        scheme.errorContainer,
        scheme.onErrorContainer,
        l10n.assistantToolStatusDenied,
      ),
      // pending 不会进入此分支，仅为穷举完整。
      ToolPermissionStatus.canceled || ToolPermissionStatus.pending => (
        Icons.hourglass_disabled_rounded,
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
        l10n.assistantToolStatusCanceled,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: ShapeDecoration(
        color: background,
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 8),
          Text(
            label,
            style: context.textTheme.labelLarge?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
