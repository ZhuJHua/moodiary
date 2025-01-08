import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:refreshed/refreshed.dart';

import '../../utils/data/pref.dart';

class DiaryDetailsState {
  Diary diary = Get.arguments[0];

  bool showAction = Get.arguments[1];

  double? get aspect => diary.aspect;

  int? get imageColor => diary.imageColor;

  RxBool isScrolling = false.obs;

  bool get diaryHeader => PrefUtil.getValue<bool>('diaryHeader')!;

  DiaryDetailsState();
}
