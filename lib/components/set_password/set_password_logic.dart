import 'package:flutter/animation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mood_diary/pages/home/setting/setting_logic.dart';
import 'package:mood_diary/utils/utils.dart';

import 'set_password_state.dart';

class SetPasswordLogic extends GetxController with GetSingleTickerProviderStateMixin {
  final SetPasswordState state = SetPasswordState();

  late AnimationController animationController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  late Animation<double> animation =
      Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: animationController, curve: Curves.easeInOut));

  late final settingLogic = Bind.find<SettingLogic>();

  @override
  void onInit() {
    // TODO: implement onInit

    super.onInit();
  }

  @override
  void onReady() {
    // TODO: implement onReady
    super.onReady();
  }

  @override
  void onClose() {
    // TODO: implement onClose
    animationController.dispose();
    super.onClose();
  }

  double interpolate(double x) {
    var step = 10.0;
    if (x <= 0.25) {
      // 第一段: (0, step) - 单调递增
      return 4 * step * x;
    } else if (x <= 0.75) {
      // 第二段: (step, -step) - 单调递减
      return step - 4 * step * (x - 0.25);
    } else {
      // 第三段: (-step, 0) - 单调递增
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
      //如果第一遍输入完成，保存记录后重新输入第二遍
      if (state.password.value.length == 4 && state.checkPassword.value.isEmpty) {
        state.checkPassword.value = state.password.value;
        state.password.value = '';
      }
      //第二次输入，进行校验
      if (state.password.value.length == 4 && state.checkPassword.value.isNotEmpty) {
        //两次输入一致
        if (state.password.value == state.checkPassword.value) {
          await setPassword();
        } else {
          animationController.forward();
          await HapticFeedback.mediumImpact();
          Future.delayed(const Duration(milliseconds: 200), () {
            animationController.reverse();
            state.password.value = '';
            state.checkPassword.value = '';
          });
        }
      }
    });
  }

  Future<void> setPassword() async {
    //lock标记为true说明开启了密码
    await Utils().prefUtil.setValue<bool>('lock', true);
    //设置密码字段
    await Utils().prefUtil.setValue<String>('password', state.password.value);
    settingLogic.state.lock.value = true;
    Utils().noticeUtil.showToast('设置成功');
    Get.backLegacy();
  }
}
