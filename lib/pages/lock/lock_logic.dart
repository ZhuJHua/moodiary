import 'package:flutter/animation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mood_diary/router/app_routes.dart';

import 'lock_state.dart';

class LockLogic extends GetxController with GetSingleTickerProviderStateMixin {
  final LockState state = LockState();
  late AnimationController animationController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  late Animation<double> animation =
      Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: animationController, curve: Curves.easeInOut));

  @override
  void onClose() {
    animationController.dispose();
    super.onClose();
  }

  double interpolate(double x) {
    var step = 10.0;
    if (x <= 0.25) {
      return 4 * step * x;
    } else if (x <= 0.75) {
      return step - 4 * step * (x - 0.25);
    } else {
      return -step + 4 * step * (x - 0.75);
    }
  }

  void deletePassword() {
    if (state.password.value.isNotEmpty) {
      state.password.value = state.password.value.substring(0, state.password.value.length - 1);
      HapticFeedback.selectionClick();
    }
  }

  Future<void> updatePassword(String value) async {
    if (state.password.value.length < 4) {
      state.password.value += value;
      HapticFeedback.selectionClick();
    }
    Future.delayed(const Duration(milliseconds: 100), () async {
      if (state.password.value.length == 4) {
        //密码正确
        if (state.password.value == state.realPassword.value) {
          checked();
        } else {
          animationController.forward();
          await HapticFeedback.mediumImpact();
          Future.delayed(const Duration(milliseconds: 200), () {
            animationController.reverse();
            state.password.value = '';
          });
        }
      }
    });
  }

  void checked() {
    //如果是启动时的锁定，就跳转到homepage
    if (state.lockType == null) {
      Get.offAllNamed(AppRoutes.homePage);
    }

    //如果是开启立即锁定后生命周期变化导致的锁定
    if (state.lockType == 'pause') {
      Get.backLegacy();
    }
  }
}
