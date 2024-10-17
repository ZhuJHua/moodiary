import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/diary.dart';

class DiaryDetailsState {
  late Diary diary;

  late bool showAction;

  double? get aspect => diary.aspect;

  int? get imageColor => diary.imageColor;

  DiaryDetailsState() {
    diary = Get.arguments[0];
    showAction = Get.arguments[1];

    ///Initialize variables
  }
}
