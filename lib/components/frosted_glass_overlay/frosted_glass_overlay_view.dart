import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:refreshed/refreshed.dart';

import 'frosted_glass_overlay_logic.dart';

class FrostedGlassOverlayComponent extends StatelessWidget {
  const FrostedGlassOverlayComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final FrostedGlassOverlayLogic logic = Get.put(FrostedGlassOverlayLogic());
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: logic.animationController,
      builder: (context, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: 10 * logic.animationController.value,
              sigmaY: 10 * logic.animationController.value),
          enabled: logic.animationController.value > 0,
          child: Opacity(
            opacity: logic.animationController.value,
            child: child,
          ),
        );
      },
      child: Center(
        child: Icon(
          Icons.security_rounded,
          color: colorScheme.onSurface,
          size: 64,
        ),
      ),
    );
  }
}
