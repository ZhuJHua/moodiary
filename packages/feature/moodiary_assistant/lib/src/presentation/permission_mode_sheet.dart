import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

String permissionModeLabel(Translations l10n, AssistantPermissionMode mode) =>
    switch (mode) {
      .confirm => l10n.assistant.permissionConfirm,
      .auto => l10n.assistant.permissionAuto,
      .full => l10n.assistant.permissionFull,
    };

String _permissionModeDes(Translations l10n, AssistantPermissionMode mode) =>
    switch (mode) {
      .confirm => l10n.assistant.permissionConfirmDes,
      .auto => l10n.assistant.permissionAutoDes,
      .full => l10n.assistant.permissionFullDes,
    };

Future<AssistantPermissionMode?> showPermissionModePicker(
  BuildContext context, {
  required AssistantPermissionMode selected,
  String? subtitle,
}) => MSheet.show<AssistantPermissionMode>(
  context,
  builder: (sheetContext) {
    final l10n = sheetContext.l10n;
    return MSheetScaffold<AssistantPermissionMode>(
      title: l10n.assistant.permissionTitle,
      subtitle: subtitle,
      icon: LucideIcons.shieldCheck,
      child: Column(
        mainAxisSize: .min,
        children: [
          for (final mode in AssistantPermissionMode.values)
            _ModeTile(
              label: permissionModeLabel(l10n, mode),
              description: _permissionModeDes(l10n, mode),
              selected: mode == selected,
              onTap: () => Navigator.of(sheetContext).pop(mode),
            ),
        ],
      ),
    );
  },
);

class _ModeTile extends StatelessWidget {
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTile({
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    return Material(
      color: selected ? colors.surfaceContainerHighest : Colors.transparent,
      borderRadius: MuiRadius.md,
      clipBehavior: .antiAlias,
      child: MInkWell(
        onTap: onTap,
        child: Padding(
          padding: const .symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(
                selected ? LucideIcons.circleCheck : LucideIcons.circle,
                size: 20,
                color: selected ? colors.onSurface : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Text(label, style: typography.bodyMedium.onSurface),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: typography.labelSmall.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
