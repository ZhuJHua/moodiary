import 'dart:ui';

import 'package:get/get.dart';
import 'package:mood_diary/pages/setting/setting_logic.dart';
import 'package:mood_diary/utils/utils.dart';

import 'color_dialog_state.dart';

class ColorDialogLogic extends GetxController {
  final ColorDialogState state = ColorDialogState();

  late SettingLogic settingLogic = Bind.find<SettingLogic>();

  @override
  void onInit() async {
    // TODO: implement onInit
    //如果支持系统颜色，获取系统颜色
    if (state.supportDynamic.value) {
      state.systemColor.value = await Utils().themeUtil.getDynamicColor();
    }
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

  //更改主题色
  Future<void> changeSeedColor(index) async {
    await Utils().prefUtil.setValue<int>('color', index);
    state.currentColor.value = index;
    settingLogic.state.color.value = index;
    Get.changeTheme(await Utils().themeUtil.buildTheme(Brightness.light));
    Get.changeTheme(await Utils().themeUtil.buildTheme(Brightness.dark));
  }
}
