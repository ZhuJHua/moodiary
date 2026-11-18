import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

class MetaTile<T> extends StatelessWidget {
  const MetaTile({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.entries,
    required this.onSelected,
    this.dragIndex,
    this.selected = false,
    this.onLongPress,
    this.trailing,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final List<MMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;
  final int? dragIndex;
  final bool selected;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Card.filled(
      margin: const .symmetric(vertical: 4),
      color: selected ? colors.secondaryContainer : colors.surfaceContainerLow,
      clipBehavior: .antiAlias,
      child: ListTile(
        selected: selected,
        onTap: onTap,
        onLongPress: onLongPress,
        leading: leading,
        title: Text(
          title,
          maxLines: 1,
          overflow: .ellipsis,
          style: context.theme.typography.titleMedium.onSurface,
        ),
        subtitle: Text(
          subtitle,
          style: context.theme.typography.labelSmall.onSurfaceVariant,
        ),
        trailing:
            trailing ??
            Row(
              mainAxisSize: .min,
              children: [
                MMenuButton<T>(
                  tooltip: context.l10n.common.more,
                  entries: entries,
                  onSelected: onSelected,
                  child: Padding(
                    padding: const .all(12),
                    child: Icon(
                      LucideIcons.ellipsisVertical,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                if (dragIndex != null)
                  ReorderableDragStartListener(
                    index: dragIndex!,
                    child: Padding(
                      padding: const .only(left: 4),
                      child: Icon(
                        LucideIcons.gripHorizontal,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
      ),
    );
  }
}

class MetaBadge extends StatelessWidget {
  const MetaBadge({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
    this.size = 42,
    this.radius = 13,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: background,
      borderRadius: .circular(radius),
    ),
    child: Icon(icon, size: size / 2, color: foreground),
  );
}
