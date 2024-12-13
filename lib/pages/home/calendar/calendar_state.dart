import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/diary.dart';

class CalendarState {
  //选中的时间
  late Rx<DateTime> selectedDate;

  late Rx<DateTime> currentMonth;

  //当前月份的日记
  late Map<Diary, GlobalKey> currentMonthDiaryMap = {};

  late RxBool isExpanded;

  late RxBool isFetching = true.obs;

  CalendarState() {
    //默认是今天
    var now = DateTime.now();
    selectedDate = now.obs;
    currentMonth = now.obs;
    isExpanded = false.obs;

    ///Initialize variables
  }
}
