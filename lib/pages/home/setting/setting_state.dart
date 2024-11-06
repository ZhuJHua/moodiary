import 'package:mood_diary/utils/utils.dart';

class SettingState {
  //当前占用空间
  String dataUsage = '';

  int themeMode = Utils().prefUtil.getValue<int>('themeMode')!;

  int color = Utils().prefUtil.getValue<int>('color')!;

  // late RxInt fontTheme;

  bool lock = Utils().prefUtil.getValue<bool>('lock')!;

  bool lockNow = Utils().prefUtil.getValue<bool>('lockNow')!;

  bool local = Utils().prefUtil.getValue<bool>('local')!;

  String customTitle = Utils().prefUtil.getValue<String>('customTitleName')!;

  SettingState() {
    // fontTheme = Utils().prefUtil.getValue<int>('fontTheme')!.obs;
  }
}
