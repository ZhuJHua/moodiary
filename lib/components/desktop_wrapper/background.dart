import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:moodiary/common/values/border.dart';

class AdaptiveBackground extends StatelessWidget {
  final Widget child;

  const AdaptiveBackground({super.key, required this.child});

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      bool showBackground = constraints.maxWidth >= 600;
      return Stack(
        children: [
          if (showBackground)
            Positioned.fill(
              child: Container(
                color: colorScheme.surfaceContainer,
                padding: const EdgeInsets.only(top: 16, right: 16, bottom: 16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: AppBorderRadius.mediumBorderRadius,
                    color: colorScheme.surface,
                  ),
                ),
              ),
            ),
          Padding(
            padding: showBackground
                ? const EdgeInsets.only(left: 8, top: 24, right: 24, bottom: 24)
                : EdgeInsets.zero,
            child: child,
          ),
          if (!_isMobile)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: GestureDetector(
                onPanStart: (_) => appWindow.startDragging(),
                behavior: HitTestBehavior.translucent,
                child: const SizedBox(height: 32.0),
              ),
            ),
        ],
      );
    });
  }
}
