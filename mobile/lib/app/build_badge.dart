import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

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
      layoutDirection: TextDirection.ltr,
      location: BannerLocation.topStart,
      color: const Color(0xA01E7F4F),
      child: child,
    );
  }
}
