import 'package:mui/mui.dart';

/// Round multi-select mark: outlined when off, primary fill with a check when on.
/// The parent decides the size; the check scales with it.
class MSelectMark extends StatelessWidget {
  final bool selected;

  final bool enabled;

  const MSelectMark({super.key, required this.selected, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: LayoutBuilder(
        builder: (context, constraints) => AnimatedContainer(
          duration: Durations.short3,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            shape: .circle,
            color: selected ? colors.primary : colors.surfaceContainerLowest,
            border: .all(
              color: selected ? colors.primary : colors.outline,
              width: 1.25,
            ),
          ),
          child: selected
              ? Icon(
                  LucideIcons.check,
                  size: constraints.biggest.shortestSide * 2 / 3,
                  color: colors.onPrimary,
                )
              : null,
        ),
      ),
    );
  }
}
