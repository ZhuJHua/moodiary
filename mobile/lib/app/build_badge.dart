import 'package:flutter/services.dart';
import 'package:mui/mui.dart';

/// Marks every Alpha route and overlay without intercepting input.
class BuildBadge extends StatelessWidget {
  const BuildBadge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (appFlavor != 'alpha') return child;

    return Banner(
      message: 'ALPHA',
      textDirection: TextDirection.ltr,
      location: BannerLocation.topStart,
      color: context.theme.success,
      child: child,
    );
  }
}
