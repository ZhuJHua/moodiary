import 'package:get/get.dart';
import 'package:mood_diary/utils/utils.dart';

import 'diary_setting_state.dart';

class DiarySettingLogic extends GetxController {
  final DiarySettingState state = DiarySettingState();

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

  //图片质量
  Future<void> quality(int value) async {
    Get.backLegacy();
    await Utils().prefUtil.setValue<int>('quality', value);
    state.quality.value = value;
  }

  //自动天气
  Future<void> autoWeather(bool value) async {
    await Utils().prefUtil.setValue<bool>('autoWeather', value);
    state.autoWeather.value = value;
  }
}
