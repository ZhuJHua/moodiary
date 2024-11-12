import 'package:get/get.dart';
import 'package:mood_diary/utils/utils.dart';

import 'diary_setting_state.dart';

class DiarySettingLogic extends GetxController {
  final DiarySettingState state = DiarySettingState();

  //图片质量
  Future<void> quality(int value) async {
    Get.backLegacy();
    await Utils().prefUtil.setValue<int>('quality', value);
    state.quality = value;
    update(['Quality']);
  }

  //自动天气
  Future<void> autoWeather(bool value) async {
    await Utils().prefUtil.setValue<bool>('autoWeather', value);
    state.autoWeather = value;
    update(['AutoWeather']);
  }

  //动态配色
  Future<void> dynamicColor(bool value) async {
    await Utils().prefUtil.setValue<bool>('dynamicColor', value);
    state.dynamicColor = value;
  }
}
