import 'package:moodiary/utils/data/pref.dart';
import 'package:refreshed/refreshed.dart';

class DiarySettingState {
  // 图片质量
  RxInt quality = PrefUtil.getValue<int>('quality')!.obs;

  // 动态配色
  RxBool dynamicColor = PrefUtil.getValue<bool>('dynamicColor')!.obs;

  // 自动天气
  RxBool autoWeather = PrefUtil.getValue<bool>('autoWeather')!.obs;

  // 日记页头图
  RxBool diaryHeader = PrefUtil.getValue<bool>('diaryHeader')!.obs;

  // 首行缩进
  RxBool firstLineIndent = PrefUtil.getValue<bool>('firstLineIndent')!.obs;

  // 自动分类
  RxBool autoCategory = PrefUtil.getValue<bool>('autoCategory')!.obs;

  // 展示写作时长
  RxBool showWriteTime = PrefUtil.getValue<bool>('showWritingTime')!.obs;

  // 展示字数统计
  RxBool showWordCount = PrefUtil.getValue<bool>('showWordCount')!.obs;

  DiarySettingState();
}
