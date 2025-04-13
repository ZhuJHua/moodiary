import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'frosted_glass_overlay_logic.dart';

class FrostedGlassOverlayComponent extends StatelessWidget {
  const FrostedGlassOverlayComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final FrostedGlassOverlayLogic logic = Get.put(FrostedGlassOverlayLogic());

    return AnimatedBuilder(
      animation: logic.animationController,
      builder: (context, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 10 * logic.animationController.value,
            sigmaY: 10 * logic.animationController.value,
          ),
          enabled: logic.animationController.value > 0,
          child: const SizedBox.shrink(),
        );
      },
    );
  }
}
