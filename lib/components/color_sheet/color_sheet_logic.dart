import 'dart:ui';

import 'package:get/get.dart';

import '../../pages/home/setting/setting_logic.dart';
import '../../utils/data/pref.dart';
import '../../utils/theme_util.dart';
import 'color_sheet_state.dart';

class ColorSheetLogic extends GetxController {
  final ColorSheetState state = ColorSheetState();

  late SettingLogic settingLogic = Bind.find<SettingLogic>();

  @override
  void onInit() {
    if (state.supportDynamic) {
      state.systemColor = Color(PrefUtil.getValue<int>('systemColor')!);
    }
    super.onInit();
  }

  int _counter = 0;

  //更改主题色
  Future<void> changeSeedColor(index) async {
    await PrefUtil.setValue<int>('color', index);
    state.currentColor = index;
    settingLogic.state.color = index;
    _counter++;
    update();
  }

  void changeTheme() async {
    _counter--;
    if (_counter > 0) return;
    Get.changeTheme(await ThemeUtil.buildTheme(Brightness.light));
    Get.changeTheme(await ThemeUtil.buildTheme(Brightness.dark));
  }
}
