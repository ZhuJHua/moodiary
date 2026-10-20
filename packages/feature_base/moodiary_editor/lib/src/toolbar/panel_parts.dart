import 'dart:math';

import 'package:mui/mui.dart';

import 'editor_command.dart';

typedef EditorExec = void Function(
  EditorCommand command, [
  Map<String, Object?>? args,
]);

Color panelGroupColor(BuildContext context) {
  final theme = context.theme;
  return theme.isDark
      ? theme.colors.surfaceContainerHigh
      : theme.colors.surfaceContainerLowest;
}

class PanelSegmentGroup extends StatelessWidget {
  final double? height;
  final List<Widget> children;

  const PanelSegmentGroup({super.key, this.height, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const .all(4),
      decoration: BoxDecoration(
        color: panelGroupColor(context),
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

class PanelSegment extends StatelessWidget {
  final bool selected;
  final VoidCallback? onTap;
  final String semanticLabel;
  final Widget child;

  const PanelSegment({
    super.key,
    this.selected = false,
    required this.onTap,
    required this.semanticLabel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    final foreground = onTap == null
        ? colors.outlineVariant
        : selected
        ? colors.onPrimary
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
            color: selected ? colors.primary : null,
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

class PanelScroll extends StatelessWidget {
  final double top;
  final double gap;
  final List<Widget> children;

  const PanelScroll({
    super.key,
    required this.top,
    required this.gap,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = max(16.0, MediaQuery.viewPaddingOf(context).bottom);
    return SingleChildScrollView(
      padding: .fromLTRB(16, top, 16, bottom),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: gap,
        children: children,
      ),
    );
  }
}

class SegmentText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const SegmentText(this.text, {super.key, required this.style});

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
