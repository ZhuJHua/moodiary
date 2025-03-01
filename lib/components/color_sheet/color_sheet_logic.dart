import 'package:moodiary/pages/home/setting/setting_logic.dart';
import 'package:moodiary/presentation/pref.dart';
import 'package:moodiary/utils/theme_util.dart';
import 'package:refreshed/refreshed.dart';

import 'color_sheet_state.dart';

class ColorSheetLogic extends GetxController {
  final ColorSheetState state = ColorSheetState();

  late SettingLogic settingLogic = Bind.find<SettingLogic>();

  //更改主题色
  Future<void> changeSeedColor(index) async {
    await PrefUtil.setValue<int>('color', index);
    state.currentColor = index;
    settingLogic.state.color = index;
    await ThemeUtil.forceUpdateTheme();
    update();
  }
}
