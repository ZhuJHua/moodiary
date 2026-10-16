import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

import 'toolbar_button.dart';

const _widthPercents = [25, 50, 75, 100];

class _FloatingCard extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Widget child;

  const _FloatingCard({required this.padding, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return ExcludeFocus(
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: .circular(14),
          border: Border.all(color: colors.surfaceContainerHighest),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class LinkBar extends StatelessWidget {
  final String href;
  final VoidCallback onOpen;
  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const LinkBar({
    super.key,
    required this.href,
    required this.onOpen,
    required this.onCopy,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.l10n.editor.toolbar;
    final colors = context.theme.colors;
    return _FloatingCard(
      padding: const .only(left: 12, right: 4),
      child: SizedBox(
        height: 44,
        child: Row(
          spacing: 4,
          children: [
            Icon(LucideIcons.link, size: 18, color: colors.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                href.replaceFirst(RegExp(r'^[a-zA-Z][\w+.-]*://'), ''),
                maxLines: 1,
                overflow: .ellipsis,
                style: context.theme.typography.bodyMedium.onSurfaceVariant,
              ),
            ),
            ToolbarIconButton(
              icon: LucideIcons.externalLink,
              tooltip: t.openLink,
              onTap: onOpen,
            ),
            ToolbarIconButton(
              icon: LucideIcons.copy,
              tooltip: t.copyLink,
              onTap: onCopy,
            ),
            ToolbarIconButton(
              icon: LucideIcons.pencil,
              tooltip: t.editLink,
              onTap: onEdit,
            ),
            ToolbarIconButton(
              icon: LucideIcons.unlink,
              tooltip: t.removeLink,
              onTap: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class WidthPicker extends StatelessWidget {
  final int? current;
  final ValueChanged<int> onPick;

  const WidthPicker({super.key, required this.current, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typo = context.theme.typography;
    return _FloatingCard(
      padding: const .all(4),
      child: Row(
        mainAxisSize: .min,
        spacing: 4,
        children: [
          for (final percent in _widthPercents)
            Semantics(
              button: true,
              selected: (current ?? 100) == percent,
              child: MInkWell(
                onTap: () => onPick(percent),
                borderRadius: .circular(10),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 60),
                  height: 40,
                  alignment: .center,
                  decoration: BoxDecoration(
                    color: (current ?? 100) == percent ? colors.primary : null,
                    borderRadius: .circular(10),
                  ),
                  child: Text(
                    '$percent%',
                    style: (current ?? 100) == percent
                        ? typo.labelLarge.onPrimary
                        : typo.labelLarge.onSurface,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class TableMenuBar extends StatelessWidget {
  final VoidCallback onToggleHeader;
  final VoidCallback onDelete;

  const TableMenuBar({
    super.key,
    required this.onToggleHeader,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.l10n.editor.toolbar;
    return _FloatingCard(
      padding: const .all(4),
      child: Row(
        mainAxisSize: .min,
        spacing: 4,
        children: [
          ToolbarLabelButton(
            icon: LucideIcons.panelTop,
            label: t.tableHeaderRow,
            onTap: onToggleHeader,
          ),
          ToolbarLabelButton(
            icon: LucideIcons.trash2,
            label: t.tableDelete,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}
