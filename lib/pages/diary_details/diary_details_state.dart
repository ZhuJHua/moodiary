import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/diary.dart';

class DiaryDetailsState {
  Diary diary = Get.arguments[0];

  bool showAction = Get.arguments[1];

  double? get aspect => diary.aspect;

  int? get imageColor => diary.imageColor;

  RxBool isScrolling = false.obs;

  DiaryDetailsState();
}
