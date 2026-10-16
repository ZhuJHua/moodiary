import 'package:mui/mui.dart';

enum ToolbarButtonTone { plain, active, pressed }

class ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final ToolbarButtonTone tone;
  final double width;
  final double height;

  const ToolbarIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.tone = .plain,
    this.width = 36,
    this.height = 36,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final (background, foreground) = switch (tone) {
      _ when onTap == null => (null, colors.outlineVariant),
      .pressed => (colors.primary, colors.onPrimary),
      .active => (colors.surfaceContainerHighest, colors.onSurface),
      .plain => (null, colors.onSurface),
    };
    return Semantics(
      button: true,
      selected: tone != .plain,
      label: tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: MInkWell(
          onTap: onTap,
          enabled: onTap != null,
          borderRadius: .circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: width,
            height: height,
            alignment: .center,
            decoration: BoxDecoration(
              color: background,
              borderRadius: .circular(10),
            ),
            child: Icon(icon, size: 20, color: foreground),
          ),
        ),
      ),
    );
  }
}

class ToolbarLabelButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool pressed;

  const ToolbarLabelButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.pressed = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final foreground = pressed ? colors.onPrimary : colors.onSurface;
    return MInkWell(
      onTap: onTap,
      borderRadius: .circular(10),
      child: Container(
        height: 36,
        padding: const .symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: pressed ? colors.primary : null,
          borderRadius: .circular(10),
        ),
        child: Row(
          mainAxisSize: .min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 4),
            Text(
              label,
              style: context.theme.typography.labelLarge.onSurface.copyWith(
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ToolbarNameChip extends StatelessWidget {
  final IconData icon;
  final String? name;
  final String placeholder;
  final String tooltip;
  final VoidCallback onTap;

  const ToolbarNameChip({
    super.key,
    required this.icon,
    required this.name,
    required this.placeholder,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final label = name?.trim() ?? '';
    final named = label.isNotEmpty;
    return Semantics(
      button: true,
      label: named ? label : placeholder,
      hint: tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: MInkWell(
          onTap: onTap,
          borderRadius: .circular(10),
          child: Container(
            height: 36,
            constraints: const BoxConstraints(maxWidth: 160),
            padding: const .symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: .circular(10),
            ),
            child: Row(
              mainAxisSize: .min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: named ? colors.onSurface : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    named ? label : placeholder,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: named
                        ? typography.labelLarge.onSurface
                        : typography.labelLarge.onSurfaceVariant,
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

class ToolbarDivider extends StatelessWidget {
  final double margin;

  const ToolbarDivider({super.key, this.margin = 4});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: .symmetric(horizontal: margin),
      color: context.theme.colors.outlineVariant,
    );
  }
}

class ToolbarContextGroup extends StatelessWidget {
  final List<Widget> children;

  const ToolbarContextGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.theme.colors.surfaceContainerHighest,
        borderRadius: .circular(10),
      ),
      child: Row(mainAxisSize: .min, children: children),
    );
  }
}
