import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FrostedGlassOverlayLogic extends GetxController
    with GetSingleTickerProviderStateMixin {
  late final AnimationController animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
  );

  void enable() {
    animationController.forward();
  }

  void disable() {
    animationController.animateTo(
      0,
      duration: const Duration(milliseconds: 50),
    );
  }

  @override
  void onClose() {
    animationController.dispose();
    super.onClose();
  }
}
