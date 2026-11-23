import 'package:mui/mui.dart';

enum MChipSize {
  small(32),
  medium(36);

  const MChipSize(this.height);
  final double height;
}

enum MChipVariant { tonal, ghost }

class MChip extends StatelessWidget {
  const MChip({
    super.key,
    required this.label,
    this.leading,
    this.trailing,
    this.selected = false,
    this.onTap,
    this.onRemove,
    this.removeTooltip,
    this.size = .small,
    this.variant = .tonal,
    this.semanticLabel,
  });

  final String label;
  final Widget? leading;
  final Widget? trailing;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final String? removeTooltip;
  final MChipSize size;
  final MChipVariant variant;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final (fill, foreground) = switch ((onTap, variant, selected)) {
      (null, _, _) => (
        colors.onSurface.withValues(alpha: 0.12),
        colors.onSurface.withValues(alpha: 0.38),
      ),
      (_, .ghost, _) => (Colors.transparent, colors.onSurfaceVariant),
      (_, .tonal, true) => (colors.primaryContainer, colors.onPrimaryContainer),
      (_, .tonal, false) => (
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
    };
    const shape = StadiumBorder();
    final removeLabel =
        removeTooltip ?? MaterialLocalizations.of(context).deleteButtonTooltip;
    return Material(
      color: fill,
      shape: shape,
      clipBehavior: .antiAlias,
      child: IconTheme.merge(
        data: IconThemeData(color: foreground),
        child: DefaultTextStyle(
          style: context.theme.typography.labelLarge.withColor(foreground),
          child: Row(
            mainAxisSize: .min,
            children: [
              Flexible(
                child: Semantics(
                  container: true,
                  button: true,
                  enabled: onTap != null,
                  selected: variant == .tonal ? selected : null,
                  label: semanticLabel ?? label,
                  child: InkWell(
                    customBorder: shape,
                    onTap: onTap,
                    child: ExcludeSemantics(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: size.height),
                        child: Padding(
                          padding: EdgeInsetsDirectional.only(
                            start: leading == null ? 12 : 10,
                            end: onRemove != null
                                ? 0
                                : trailing == null
                                ? 12
                                : 10,
                          ),
                          child: Row(
                            mainAxisSize: .min,
                            spacing: 6,
                            children: [
                              ?leading,
                              Flexible(
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: .ellipsis,
                                ),
                              ),
                              ?trailing,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (onRemove != null)
                Semantics(
                  container: true,
                  button: true,
                  label: removeLabel,
                  child: Tooltip(
                    message: removeLabel,
                    excludeFromSemantics: true,
                    child: InkWell(
                      customBorder: shape,
                      onTap: onRemove,
                      child: SizedBox(
                        height: size.height,
                        child: const Padding(
                          padding: EdgeInsetsDirectional.only(
                            start: 6,
                            end: 10,
                          ),
                          child: Icon(LucideIcons.x, size: 16),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
