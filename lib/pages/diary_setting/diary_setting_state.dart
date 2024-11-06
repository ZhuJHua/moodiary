import 'package:mood_diary/utils/utils.dart';

class DiarySettingState {
  // 图片质量
  int quality = Utils().prefUtil.getValue<int>('quality')!;

  // 自动获取天气
  bool dynamicColor = Utils().prefUtil.getValue<bool>('dynamicColor')!;
  bool autoWeather = Utils().prefUtil.getValue<bool>('autoWeather')!;

  DiarySettingState();
}
