import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/diary.dart';

class DiaryState {
  late Diary diary;

  DiaryState() {
    diary = Get.arguments;

    ///Initialize variables
  }
}
