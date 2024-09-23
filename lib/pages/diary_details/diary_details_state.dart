import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/diary.dart';

class DiaryDetailsState {
  late Diary diary;

  late bool showAction;

  DiaryDetailsState() {
    diary = Get.arguments[0];
    showAction = Get.arguments[1];

    ///Initialize variables
  }
}
