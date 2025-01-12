import 'package:refreshed/refreshed.dart';

import '../../../utils/data/pref.dart';

class SettingState {
  //当前占用空间
  String dataUsage = '';

  int themeMode = PrefUtil.getValue<int>('themeMode')!;

  int color = PrefUtil.getValue<int>('color')!;

  late RxInt fontTheme;

  bool lock = PrefUtil.getValue<bool>('lock')!;

  bool lockNow = PrefUtil.getValue<bool>('lockNow')!;

  bool local = PrefUtil.getValue<bool>('local')!;

  String customTitle = PrefUtil.getValue<String>('customTitleName')!;

  RxBool backendPrivacy = PrefUtil.getValue<bool>('backendPrivacy')!.obs;

  SettingState() {
    fontTheme = PrefUtil.getValue<int>('fontTheme')!.obs;
  }
}
