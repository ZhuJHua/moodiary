import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../utils/data/isar.dart';
import 'calendar_state.dart';

class CalendarLogic extends GetxController {
  final CalendarState state = CalendarState();

  @override
  void onReady() async {
    await getMonthDiary(state.currentMonth.value);
    super.onReady();
  }

  // 获取当前月份的日记
  Future<void> getMonthDiary(DateTime value) async {
    state.isFetching.value = true;
    final diaryList = await IsarUtil.getDiaryByMonth(value.year, value.month);
    var dateWithDiaryList = <DateTime>[];
    // 获取有日记的日期，只需要年月日
    for (var diary in diaryList) {
      // 如果不存在当前日期，则添加
      var time = diary.time;
      if (!dateWithDiaryList.contains(DateTime(time.year, time.month, time.day))) {
        dateWithDiaryList.add(DateTime(time.year, time.month, time.day));
      }
    }
    state.selectedDate.value = DateTime.now();
    state.currentMonthDiaryMap = {for (var e in diaryList) e: GlobalKey()};
    update();
    state.isFetching.value = false;
  }

  // 选中日期后滚动到该日期
  Future<void> animateToSelectedDate(DateTime value) async {
    state.selectedDate.value = value;
    // 根据日期找到当前列表中第一篇日记对应的 GlobalKey，然后滚动到该日记
    var key = state.currentMonthDiaryMap.entries
        .firstWhere((element) =>
            element.key.yMd == '${value.year.toString()}/${value.month.toString()}/${value.day.toString()}')
        .value;
    Scrollable.ensureVisible(key.currentContext!, duration: Duration(milliseconds: 300));
  }

  // // 选中日期后重新获取日记
  // Future<void> updateDate(DateTime value) async {
  //   state.selectedDate.value = value;
  //   await getDiary();
  // }

  void open(value) {
    state.isExpanded.value = value;
  }
}
