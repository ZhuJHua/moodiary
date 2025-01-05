import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/diary.dart';

class CalendarState {
  late Rx<DateTime> currentMonth = DateTime.now().obs;

  //当前月份的日记
  late RxList<Diary> currentMonthDiaryList = <Diary>[].obs;

  late RxBool isFetching = true.obs;

  late RxBool isControllerScrolling = false.obs;

  double velocityThreshold = 800;

  bool isUp = false;

  CalendarState();
}
