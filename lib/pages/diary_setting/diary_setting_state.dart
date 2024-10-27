import 'package:get/get.dart';
import 'package:mood_diary/utils/utils.dart';

class DiarySettingState {
  // 图片质量
  late RxInt quality;

  // 自动获取天气

  late RxBool autoWeather;

  DiarySettingState() {
    quality = Utils().prefUtil.getValue<int>('quality')!.obs;
    autoWeather = Utils().prefUtil.getValue<bool>('autoWeather')!.obs;
  }
}
