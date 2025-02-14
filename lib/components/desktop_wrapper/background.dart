import 'package:flutter/material.dart';
import 'package:moodiary/common/values/border.dart';

class AdaptiveBackground extends StatelessWidget {
  final Widget child;

  const AdaptiveBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      final bool showBackground = constraints.maxWidth >= 512;
      if (!showBackground) return child;
      return Container(
        color: colorScheme.surfaceContainer,
        padding: const EdgeInsets.only(
          top: 8,
          right: 8,
          bottom: 8,
        ),
        child: ClipRRect(
          borderRadius: AppBorderRadius.mediumBorderRadius,
          child: ColoredBox(
            color: colorScheme.surface,
            child: child,
          ),
        ),
      );
    });
  }
}

class PageAdaptiveBackground extends StatelessWidget {
  final Widget child;

  final bool isHome;

  const PageAdaptiveBackground({
    super.key,
    required this.child,
    this.isHome = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isHome) return child;
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      final bool showBackground = constraints.maxWidth >= 600;
      if (!showBackground) return child;
      return Container(
        color: colorScheme.surfaceContainer,
        padding: const EdgeInsets.all(8.0),
        child: ClipRRect(
          borderRadius: AppBorderRadius.mediumBorderRadius,
          child: child,
        ),
      );
    });
  }
}
