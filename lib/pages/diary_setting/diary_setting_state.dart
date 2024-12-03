import 'package:get/get.dart';
import 'package:mood_diary/utils/utils.dart';

class DiarySettingState {
  // 图片质量
  RxInt quality = Utils().prefUtil.getValue<int>('quality')!.obs;

  // 动态配色
  RxBool dynamicColor = Utils().prefUtil.getValue<bool>('dynamicColor')!.obs;

  // 自动天气
  RxBool autoWeather = Utils().prefUtil.getValue<bool>('autoWeather')!.obs;

  // 日记页头图
  RxBool diaryHeader = Utils().prefUtil.getValue<bool>('diaryHeader')!.obs;

  // 首行缩进
  RxBool firstLineIndent = Utils().prefUtil.getValue<bool>('firstLineIndent')!.obs;

  // 自动分类
  RxBool autoCategory = Utils().prefUtil.getValue<bool>('autoCategory')!.obs;

  // 展示写作时长
  RxBool showWriteTime = Utils().prefUtil.getValue<bool>('showWritingTime')!.obs;

  // 展示字数统计
  RxBool showWordCount = Utils().prefUtil.getValue<bool>('showWordCount')!.obs;

  DiarySettingState();
}
