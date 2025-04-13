import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/values/border.dart';

class AdaptiveBackground extends StatelessWidget {
  final Widget child;

  const AdaptiveBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool showBackground = constraints.maxWidth >= 512;
        if (!showBackground) return child;
        return Container(
          color: context.theme.colorScheme.surfaceContainer,
          padding: const EdgeInsets.only(top: 8, right: 8, bottom: 8),
          child: ClipRRect(
            borderRadius: AppBorderRadius.largeBorderRadius,
            child: ColoredBox(
              color: context.theme.colorScheme.surface,
              child: child,
            ),
          ),
        );
      },
    );
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool showBackground = constraints.maxWidth >= 600;
        if (!showBackground) return child;
        return Container(
          color: context.theme.colorScheme.surfaceContainer,
          padding: const EdgeInsets.all(8.0),
          child: ClipRRect(
            borderRadius: AppBorderRadius.largeBorderRadius,
            child: child,
          ),
        );
      },
    );
  }
}
