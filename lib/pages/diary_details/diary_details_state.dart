import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/diary.dart';

class DiaryDetailsState {
  late Diary diary;

  DiaryDetailsState() {
    diary = Get.arguments;

    ///Initialize variables
  }
}
