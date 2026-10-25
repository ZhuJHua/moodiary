import 'package:mui/mui.dart';

// 色调分段：surfaceContainerHigh 的轨道里嵌 secondaryContainer 的选中块。
// 与 material 的 SegmentedButton（描边 + 勾选图标）是两种视觉，按场景选用。
class MSegmentGroup extends StatelessWidget {
  final double? height;
  final List<Widget> children;

  const MSegmentGroup({super.key, this.height, required this.children});

  static Color trackColor(BuildContext context) =>
      context.theme.colors.surfaceContainerHigh;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const .all(4),
      decoration: BoxDecoration(
        color: trackColor(context),
        borderRadius: .circular(context.theme.radii.md),
      ),
      child: Row(
        crossAxisAlignment: .stretch,
        spacing: 2,
        children: [for (final child in children) Expanded(child: child)],
      ),
    );
  }
}

class MSegment extends StatelessWidget {
  final bool selected;
  final VoidCallback? onTap;
  final String semanticLabel;
  final Widget child;

  const MSegment({
    super.key,
    this.selected = false,
    required this.onTap,
    required this.semanticLabel,
    required this.child,
  });

  static Color selectedColor(BuildContext context) =>
      context.theme.colors.secondaryContainer;

  static Color selectedForeground(BuildContext context) =>
      context.theme.colors.onSecondaryContainer;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    final foreground = onTap == null
        ? colors.onSurface.withValues(alpha: theme.states.disabledOpacity)
        : selected
        ? selectedForeground(context)
        : colors.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: MInkWell(
        onTap: onTap,
        enabled: onTap != null,
        borderRadius: .circular(theme.radii.sm),
        child: Container(
          alignment: .center,
          decoration: BoxDecoration(
            color: selected ? selectedColor(context) : null,
            borderRadius: .circular(theme.radii.sm),
          ),
          child: IconTheme.merge(
            data: IconThemeData(color: foreground),
            child: child,
          ),
        ),
      ),
    );
  }
}

// 跟随所在 MSegment 的前景色（选中 / 禁用）
class MSegmentText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const MSegmentText(this.text, {super.key, required this.style});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: .ellipsis,
      style: style.copyWith(color: IconTheme.of(context).color),
    );
  }
}

class MSegmentOption<T> {
  final T value;
  final String label;
  final IconData? icon;

  const MSegmentOption({required this.value, required this.label, this.icon});
}

// 单选的常用形态；多选、混排图标与自定义内容直接组合 MSegmentGroup + MSegment
class MSegmentedControl<T> extends StatelessWidget {
  final List<MSegmentOption<T>> options;
  final T selected;

  // 为 null 时整组禁用
  final ValueChanged<T>? onChanged;

  final double height;

  const MSegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    final style = context.theme.typography.labelLarge.onSurface;
    final changed = onChanged;
    return MSegmentGroup(
      height: height,
      children: [
        for (final option in options)
          MSegment(
            selected: option.value == selected,
            onTap: changed == null ? null : () => changed(option.value),
            semanticLabel: option.label,
            child: option.icon == null
                ? MSegmentText(option.label, style: style)
                : Row(
                    mainAxisSize: .min,
                    spacing: 6,
                    children: [
                      Icon(option.icon, size: 18),
                      Flexible(child: MSegmentText(option.label, style: style)),
                    ],
                  ),
          ),
      ],
    );
  }
}
