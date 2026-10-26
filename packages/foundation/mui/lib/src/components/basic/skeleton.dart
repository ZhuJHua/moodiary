import 'package:mui/mui.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Static, theme-aware loading bones, with the surrounding surfaces preserved.
class MSkeleton extends StatelessWidget {
  const MSkeleton({super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return SkeletonizerConfig(
      data: SkeletonizerConfigData(
        brightness: theme.brightness,
        // false preserves Card/Container paints; content shapes opt into bones.
        ignoreContainers: false,
        effectResolver: (_) =>
            SolidColorEffect(color: theme.colors.surfaceContainerHighest),
      ),
      child: Skeletonizer(enabled: enabled, child: child),
    );
  }
}
