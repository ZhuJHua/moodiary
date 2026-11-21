import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as liquid;
import 'package:mui/mui.dart';

import 'glass_platform.dart';

class MGlassApp extends StatelessWidget {
  const MGlassApp({super.key, required this.child});

  final Widget child;

  static Future<void> initialize() async {
    if (usesLiquidGlass) {
      await liquid.LiquidGlassWidgets.initialize(
        enablePerformanceMonitor: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!usesLiquidGlass) return child;

    return liquid.LiquidGlassWidgets.wrap(
      theme: liquid.GlassThemeData.simple(quality: liquid.GlassQuality.premium),
      brightnessResolver: Theme.maybeBrightnessOf,
      child: child,
    );
  }
}
