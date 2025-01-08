import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mood_diary/pages/home/setting/setting_logic.dart';
import 'package:refreshed/refreshed.dart';

import '../../utils/data/pref.dart';
import '../../utils/notice_util.dart';
import 'set_password_state.dart';

class SetPasswordLogic extends GetxController
    with GetSingleTickerProviderStateMixin {
  final SetPasswordState state = SetPasswordState();

  late AnimationController animationController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 200));
  late Animation<double> animation = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: animationController, curve: Curves.easeInOut));

  late final settingLogic = Bind.find<SettingLogic>();

  @override
  void onClose() {
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
    if (state.password.isNotEmpty) {
      state.password = state.password.substring(0, state.password.length - 1);
      update();
      HapticFeedback.selectionClick();
    }
  }

  Future<void> updatePassword(String value, BuildContext context) async {
    if (state.password.length < 4) {
      state.password += value;
      update();
      HapticFeedback.selectionClick();
    }
    Future.delayed(const Duration(milliseconds: 100), () async {
      //如果第一遍输入完成，保存记录后重新输入第二遍
      if (state.password.length == 4 && state.checkPassword.isEmpty) {
        state.checkPassword = state.password;
        state.password = '';
        update();
      }
      //第二次输入，进行校验
      if (state.password.length == 4 && state.checkPassword.isNotEmpty) {
        //两次输入一致
        if (state.password == state.checkPassword) {
          if (context.mounted) await setPassword(context);
        } else {
          animationController.forward();
          await HapticFeedback.mediumImpact();
          Future.delayed(const Duration(milliseconds: 200), () {
            animationController.reverse();
            state.password = '';
            state.checkPassword = '';
            update();
          });
        }
      }
    });
  }

  Future<void> setPassword(BuildContext context) async {
    //lock标记为true说明开启了密码
    await PrefUtil.setValue<bool>('lock', true);
    //设置密码字段
    await PrefUtil.setValue<String>('password', state.password);
    settingLogic.state.lock = true;
    settingLogic.update(['Lock']);
    NoticeUtil.showToast('设置成功');
    if (context.mounted) Navigator.pop(context);
  }
}
