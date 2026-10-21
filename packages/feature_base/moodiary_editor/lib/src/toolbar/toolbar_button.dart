import 'package:mui/mui.dart';

import 'panel_parts.dart';

enum ToolbarButtonTone { plain, active, on }

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
      _ when onTap == null => (
        null,
        colors.onSurface.withValues(
          alpha: context.theme.states.disabledOpacity,
        ),
      ),
      .on || .active => (
        panelSelectedColor(context),
        panelSelectedForeground(context),
      ),
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
          borderRadius: .circular(context.theme.radii.sm),
          child: Container(
            width: width,
            height: height,
            alignment: .center,
            decoration: BoxDecoration(
              color: background,
              borderRadius: .circular(context.theme.radii.sm),
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
    final foreground = pressed
        ? panelSelectedForeground(context)
        : colors.onSurface;
    return MInkWell(
      onTap: onTap,
      borderRadius: .circular(context.theme.radii.sm),
      child: Container(
        height: 36,
        padding: const .only(left: 10, right: 12),
        decoration: BoxDecoration(
          color: pressed ? panelSelectedColor(context) : null,
          borderRadius: .circular(context.theme.radii.sm),
        ),
        child: Row(
          mainAxisSize: .min,
          spacing: 6,
          children: [
            Icon(icon, size: 16, color: foreground),
            Text(
              label,
              style: context.theme.typography.labelLarge.withColor(foreground),
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
    final foreground = named
        ? panelSelectedForeground(context)
        : colors.onSurfaceVariant;
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
          borderRadius: .circular(context.theme.radii.sm),
          child: Container(
            height: 36,
            constraints: const BoxConstraints(maxWidth: 160),
            padding: const .symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: panelSelectedColor(context),
              borderRadius: .circular(context.theme.radii.sm),
            ),
            child: Row(
              mainAxisSize: .min,
              spacing: 8,
              children: [
                Icon(icon, size: 16, color: foreground),
                Flexible(
                  child: Text(
                    named ? label : placeholder,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: typography.labelLarge.withColor(foreground),
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
    return SizedBox(
      height: 20,
      child: VerticalDivider(
        width: margin * 2 + 1,
        thickness: 1,
        color: context.theme.colors.outlineVariant,
      ),
    );
  }
}

class ToolbarContextGroup extends StatelessWidget {
  final List<Widget> children;

  const ToolbarContextGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const .all(2),
      decoration: BoxDecoration(
        color: panelGroupColor(context),
        borderRadius: .circular(context.theme.radii.md),
      ),
      child: Row(mainAxisSize: .min, spacing: 2, children: children),
    );
  }
}
