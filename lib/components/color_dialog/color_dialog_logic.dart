import 'dart:ui';

import 'package:mood_diary/pages/home/setting/setting_logic.dart';
import 'package:mood_diary/utils/theme_util.dart';
import 'package:refreshed/refreshed.dart';

import '../../utils/data/pref.dart';
import 'color_dialog_state.dart';

class ColorDialogLogic extends GetxController {
  final ColorDialogState state = ColorDialogState();

  late SettingLogic settingLogic = Bind.find<SettingLogic>();

  @override
  void onReady() {
    //如果支持系统颜色，获取系统颜色
    if (state.supportDynamic) {
      state.systemColor = Color(PrefUtil.getValue<int>('systemColor')!);
      update();
    }
    super.onReady();
  }

  //更改主题色
  Future<void> changeSeedColor(index) async {
    await PrefUtil.setValue<int>('color', index);
    state.currentColor = index;
    settingLogic.state.color = index;
    update();
    Get.changeTheme(await ThemeUtil.buildTheme(Brightness.light));
    Get.changeTheme(await ThemeUtil.buildTheme(Brightness.dark));
  }
}
