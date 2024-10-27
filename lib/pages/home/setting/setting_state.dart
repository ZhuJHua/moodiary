import 'package:get/get.dart';
import 'package:mood_diary/utils/utils.dart';

class SettingState {
  //当前占用空间
  late RxString dataUsage;

  late RxInt themeMode;

  late RxInt color;

  late RxBool dynamicColor;


  late RxInt fontTheme;

  late RxBool getWeather;
  late RxBool lock;

  late RxBool lockNow;

  late RxBool local;

  late RxString customTitle;

  SettingState() {
    dataUsage = ''.obs;
    themeMode = Utils().prefUtil.getValue<int>('themeMode')!.obs;
    color = Utils().prefUtil.getValue<int>('color')!.obs;
    dynamicColor = Utils().prefUtil.getValue<bool>('dynamicColor')!.obs;

    fontTheme = Utils().prefUtil.getValue<int>('fontTheme')!.obs;
    getWeather = Utils().prefUtil.getValue<bool>('getWeather')!.obs;
    lock = Utils().prefUtil.getValue<bool>('lock')!.obs;
    lockNow = Utils().prefUtil.getValue<bool>('lockNow')!.obs;
    local = Utils().prefUtil.getValue<bool>('local')!.obs;
    customTitle = Utils().prefUtil.getValue<String>('customTitleName')!.obs;

    ///Initialize variables
  }
}
