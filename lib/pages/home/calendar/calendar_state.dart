import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/diary.dart';

class CalendarState {
  //选中的时间
  late Rx<DateTime> selectedDate;

  late Rx<DateTime> currentMonth;

  //包含日记的日期
  late RxList<DateTime> dateHasDiary;

  //当前选中日期内的日记列表
  late RxList<Diary> diaryList;

  late RxBool isExpanded;

  late RxBool isFetching = true.obs;

  CalendarState() {
    //默认是今天
    var now = DateTime.now();
    selectedDate = now.obs;
    currentMonth = now.obs;
    dateHasDiary = <DateTime>[].obs;
    diaryList = <Diary>[].obs;
    isExpanded = false.obs;

    ///Initialize variables
  }
}
