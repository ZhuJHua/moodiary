import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/pages/home/setting/setting_logic.dart';
import 'package:mood_diary/utils/utils.dart';

import 'theme_mode_dialog_state.dart';

class ThemeModeDialogLogic extends GetxController {
  final ThemeModeDialogState state = ThemeModeDialogState();
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
    super.onClose();
  }

  //修改颜色模式
  Future<void> changeThemeMode(int value) async {
    await Utils().prefUtil.setValue<int>('themeMode', value);
    state.themeMode = value;
    settingLogic.state.themeMode.value = value;
    Get.changeThemeMode(ThemeMode.values[value]);
    Get.forceAppUpdate();
  }
}
