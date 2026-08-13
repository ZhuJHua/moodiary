import 'package:genui/genui.dart' as genui;
import 'package:moodiary_assistant/src/application/tool_permission_coordinator.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/presentation/assistant_tool_ui.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:mui/mui.dart';

final genui.Catalog assistantGenUiCatalog = genui.Catalog([
  _toolPermissionCard,
], catalogId: assistantGenUiCatalogId);

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
    final name = event.toMap()['name'];
    if (name is! String) return false;
    onAction(genUiContext.surfaceId, name);
    return true;
  }
}

final genui.CatalogItem _toolPermissionCard = genui.CatalogItem(
  name: toolPermissionCardComponent,
  dataSchema: .object(
    description:
        'A Material 3 card that asks the user to approve an assistant tool '
        'call, then shows the resolved decision in place.',
    properties: {
      'tool': .string(
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
    final tool = AssistantTool.values.firstWhere((t) => t.id == data['tool']);
    return genui.BoundString(
      dataContext: itemContext.dataContext,
      value: data['status'],
      builder: (context, statusId) => _ToolPermissionCardView(
        tool: tool,
        status: .fromId(statusId),
        onAction: (name) => itemContext.dispatchEvent(
          genui.UserActionEvent(name: name, sourceComponentId: itemContext.id),
        ),
      ),
    );
  },
);

/// Chat-native permission bubble: shares the assistant bubble's surface color
/// and asymmetric tail so it reads as part of the conversation rather than a
/// detached form. A hairline outline is the only cue that it is interactive.
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
    final scheme = context.theme.colors;
    final l10n = context.l10n;
    final display = assistantToolDisplay(context, tool);
    final dangerous = tool.dangerous;
    final pending = status == .pending;

    // 三档权限对应三种容器色：只读（理论上不会走到这张卡）primary，写入 tertiary，破坏性 error。
    final (chipColor, onChipColor) = switch (tool.permission) {
      .dangerous => (scheme.errorContainer, scheme.onErrorContainer),
      .approval => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      .none => (scheme.primaryContainer, scheme.onPrimaryContainer),
    };

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: const .only(
          topLeft: .circular(16),
          topRight: .circular(16),
          bottomLeft: .circular(4),
          bottomRight: .circular(16),
        ),
        border: .all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      padding: const .all(14),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: chipColor,
                  borderRadius: .circular(11),
                ),
                child: Icon(display.icon, size: 20, color: onChipColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Text(
                      display.title,
                      style: context
                          .theme
                          .typography
                          .titleSmall
                          .emphasized
                          .onSurface,
                    ),
                    Text(
                      l10n.assistant.toolPermissionTitle,
                      style:
                          context.theme.typography.bodySmall.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            display.description,
            style: context.theme.typography.bodyMedium.onSurfaceVariant
                .copyWith(height: 1.35),
          ),
          if (dangerous && pending) ...[
            const SizedBox(height: 12),
            _DangerNote(text: l10n.assistant.toolPermissionDangerNote),
          ],
          const SizedBox(height: 12),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: .centerLeft,
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
                      alignment: .centerLeft,
                      child: _DecisionBadge(status: status),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DangerNote extends StatelessWidget {
  final String text;

  const _DangerNote({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Container(
      padding: const .symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: .circular(12),
      ),
      child: Row(
        crossAxisAlignment: .start,
        children: [
          Icon(
            LucideIcons.triangleAlert,
            size: 18,
            color: scheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: context.theme.typography.bodySmall.onErrorContainer
                  .copyWith(height: 1.3),
            ),
          ),
        ],
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
    final scheme = context.theme.colors;
    final l10n = context.l10n;
    return OverflowBar(
      alignment: .end,
      overflowAlignment: .end,
      spacing: 8,
      overflowSpacing: 4,
      children: [
        TextButton(
          onPressed: () => onAction(toolPermissionActionDeny),
          style: TextButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
          child: Text(l10n.assistant.toolDeny),
        ),
        TextButton(
          onPressed: () => onAction(toolPermissionActionAllowAlways),
          style: dangerous
              ? TextButton.styleFrom(foregroundColor: scheme.error)
              : null,
          child: Text(l10n.assistant.toolAllowAlways),
        ),
        FilledButton(
          onPressed: () => onAction(toolPermissionActionAllowOnce),
          style: FilledButton.styleFrom(visualDensity: .compact),
          child: Text(l10n.assistant.toolAllowOnce),
        ),
      ],
    );
  }
}

class _DecisionBadge extends StatelessWidget {
  final ToolPermissionStatus status;

  const _DecisionBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final l10n = context.l10n;
    final (icon, background, foreground, label) = switch (status) {
      .allowedOnce => (
        LucideIcons.circleCheck,
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        l10n.assistant.toolStatusAllowedOnce,
      ),
      .allowedAlways => (
        LucideIcons.badgeCheck,
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        l10n.assistant.toolAlwaysAllowedHint,
      ),
      .denied => (
        LucideIcons.circleX,
        scheme.errorContainer,
        scheme.onErrorContainer,
        l10n.assistant.toolStatusDenied,
      ),
      .canceled || .pending => (
        LucideIcons.timerOff,
        scheme.surfaceContainerHigh,
        scheme.onSurfaceVariant,
        l10n.assistant.toolStatusCanceled,
      ),
    };
    return Container(
      padding: const .symmetric(horizontal: 12, vertical: 7),
      decoration: ShapeDecoration(
        color: background,
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: .min,
        children: [
          Icon(icon, size: 17, color: foreground),
          const SizedBox(width: 7),
          Text(
            label,
            style: context.theme.typography.labelLarge.onSurface.copyWith(
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
