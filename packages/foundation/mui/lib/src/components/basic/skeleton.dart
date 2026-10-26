import 'package:mui/mui.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Theme-aware loading bones, with the surrounding surfaces preserved.
class MSkeleton extends StatelessWidget {
  const MSkeleton({super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final base = theme.colors.surfaceContainerHighest;
    final highlight = Color.lerp(
      base,
      theme.isDark
          ? theme.colors.onSurface
          : theme.colors.surfaceContainerLowest,
      theme.isDark ? .08 : .65,
    )!;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return SkeletonizerConfig(
      data: SkeletonizerConfigData(
        brightness: theme.brightness,
        // false preserves Card/Container paints; content shapes opt into bones.
        ignoreContainers: false,
        effectResolver: (_) => reduceMotion
            ? SolidColorEffect(color: base)
            : ShimmerEffect(baseColor: base, highlightColor: highlight),
      ),
      child: Skeletonizer(enabled: enabled, child: child),
    );
  }
}
