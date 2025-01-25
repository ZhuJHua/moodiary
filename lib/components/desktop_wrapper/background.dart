import 'dart:io';

import 'package:flutter/material.dart';
import 'package:moodiary/common/values/border.dart';

class AdaptiveBackground extends StatelessWidget {
  final Widget child;

  const AdaptiveBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final toolbarHeight = Platform.isMacOS ? 16.0 : 28.0;
    return LayoutBuilder(builder: (context, constraints) {
      final bool showBackground = constraints.maxWidth >= 512;
      if (!showBackground) return child;
      return Container(
        color: colorScheme.surfaceContainer,
        padding: EdgeInsets.only(top: toolbarHeight, right: 16, bottom: 16),
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            borderRadius: AppBorderRadius.mediumBorderRadius,
            color: colorScheme.surface,
          ),
          child: child,
        ),
      );
    });
  }
}
