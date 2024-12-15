import 'package:flutter/animation.dart';
import 'package:get/get.dart';

class ExpandButtonLogic extends GetxController with GetSingleTickerProviderStateMixin {
  late final AnimationController animationController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

  late final Animation<double> animation = CurvedAnimation(parent: animationController, curve: Curves.easeInOutQuart);

  @override
  void onClose() {
    animationController.dispose();
    super.onClose();
  }

  void animatedIcon() {
    if (animationController.isCompleted) {
      animationController.reverse();
    } else {
      animationController.forward();
    }
  }
}
