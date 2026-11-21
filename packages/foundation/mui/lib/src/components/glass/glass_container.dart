import 'package:glassmorphism/glassmorphism.dart' as frosted;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as liquid;
import 'package:mui/mui.dart';

import 'glass_platform.dart';

class MGlassContainer extends StatelessWidget {
  const MGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.padding = EdgeInsets.zero,
  }) : _shape = BoxShape.rectangle;

  const MGlassContainer.card({
    super.key,
    required this.child,
    this.borderRadius = 12,
    this.padding = const EdgeInsets.all(16),
  }) : _shape = BoxShape.rectangle;

  const MGlassContainer.circle({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  }) : borderRadius = 0,
       _shape = BoxShape.circle;

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final BoxShape _shape;

  @override
  Widget build(BuildContext context) {
    if (usesLiquidGlass) {
      return liquid.GlassContainer(
        shape: _shape == BoxShape.circle
            ? const liquid.LiquidOval()
            : liquid.LiquidRoundedRectangle(borderRadius: borderRadius),
        useOwnLayer: true,
        padding: padding,
        child: child,
      );
    }

    final theme = context.theme;
    final colors = theme.colors;
    final tint = theme.isDark
        ? colors.surfaceContainerHigh
        : colors.surfaceContainer;
    return frosted.GlassmorphicContainer(
      shape: _shape,
      borderRadius: borderRadius,
      padding: padding,
      clipBehavior: Clip.none,
      blur: 10,
      border: theme.borders.hairline,
      linearGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [tint.withValues(alpha: 0.66), tint.withValues(alpha: 0.52)],
      ),
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colors.outlineVariant,
          colors.outlineVariant.withValues(alpha: 0.45),
        ],
      ),
      child: child,
    );
  }
}
