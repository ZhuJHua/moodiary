import 'package:get/get.dart';

import '../../utils/data/pref.dart';
import 'diary_setting_state.dart';

class DiarySettingLogic extends GetxController {
  final DiarySettingState state = DiarySettingState();

  //图片质量
  Future<void> quality(int value) async {
    Get.backLegacy();
    await PrefUtil.setValue<int>('quality', value);
    state.quality.value = value;
  }

  //自动天气
  Future<void> autoWeather(bool value) async {
    await PrefUtil.setValue<bool>('autoWeather', value);
    state.autoWeather.value = value;
  }

  //动态配色
  Future<void> dynamicColor(bool value) async {
    await PrefUtil.setValue<bool>('dynamicColor', value);
    state.dynamicColor.value = value;
  }

  // 日记页头图
  Future<void> diaryHeader(bool value) async {
    await PrefUtil.setValue<bool>('diaryHeader', value);
    state.diaryHeader.value = value;
  }

  // 首行缩进
  Future<void> firstLineIndent(bool value) async {
    await PrefUtil.setValue<bool>('firstLineIndent', value);
    state.firstLineIndent.value = value;
  }

  // 自动设置分类
  Future<void> autoCategory(bool value) async {
    await PrefUtil.setValue<bool>('autoCategory', value);
    state.autoCategory.value = value;
  }

  // 展示写作时长
  Future<void> showWriteTime(bool value) async {
    await PrefUtil.setValue<bool>('showWritingTime', value);
    state.showWriteTime.value = value;
  }

  // 展示字数统计
  Future<void> showWordCount(bool value) async {
    await PrefUtil.setValue<bool>('showWordCount', value);
    state.showWordCount.value = value;
  }
}
