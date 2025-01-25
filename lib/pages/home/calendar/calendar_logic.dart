import 'package:flutter/material.dart';
import 'package:moodiary/presentation/isar.dart';
import 'package:moodiary/utils/log_util.dart';
import 'package:refreshed/refreshed.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'calendar_state.dart';

class CalendarLogic extends GetxController {
  final CalendarState state = CalendarState();

  late final ItemScrollController itemScrollController = ItemScrollController();
  late final ScrollOffsetController scrollOffsetController =
      ScrollOffsetController();
  late final ItemPositionsListener itemPositionsListener =
      ItemPositionsListener.create();
  late final ScrollOffsetListener scrollOffsetListener =
      ScrollOffsetListener.create();

  late final ExpansionTileController expansionTileController =
      ExpansionTileController();

  @override
  void onReady() async {
    await getMonthDiary(state.currentMonth.value);

    super.onReady();
  }

  // 获取当前月份的日记
  Future<void> getMonthDiary(DateTime value) async {
    state.isFetching.value = true;
    state.currentMonth.value = value;
    // state.currentMonthDiaryList.value =
    //     await IsarUtil.getDiaryByMonth(value.year, value.month);
    state.currentMonthDiaryList.value = await IsarUtil.getAllDiariesSorted();
    state.isFetching.value = false;
  }

  int _pendingScrollOperations = 0;

  Future<void> animateToSelectedDateWithLock(DateTime value) async {
    final index = state.currentMonthDiaryList.indexWhere((element) =>
        element.yMd == '${value.year}/${value.month}/${value.day}');
    _pendingScrollOperations++;
    state.isControllerScrolling.value = true;
    try {
      await itemScrollController.scrollTo(
          index: index,
          duration: const Duration(seconds: 1),
          curve: Curves.easeInOutQuart);
    } finally {
      _pendingScrollOperations--;
      if (_pendingScrollOperations == 0) {
        state.isControllerScrolling.value = false;
      }
    }
  }

  void onVerticalDragEnd(DragEndDetails details) {
    final double velocity = details.velocity.pixelsPerSecond.dy;
    LogUtil.printInfo(velocity);
    if (velocity > state.velocityThreshold) {
      LogUtil.printInfo('1');
      open(state.isUp);
    }
  }

  // // 选中日期后重新获取日记
  // Future<void> updateDate(DateTime value) async {
  //   state.selectedDate.value = value;
  //   await getDiary();
  // }

  void open(value) {
    if (value && !expansionTileController.isExpanded) {
      expansionTileController.expand();
    } else if (!value && expansionTileController.isExpanded) {
      expansionTileController.collapse();
    }
  }

  DateTime? findLatestDateInMonth(List<DateTime> dates, int year, int month) {
    // 过滤出符合条件的日期
    final List<DateTime> filteredDates = dates.where((date) {
      return date.year == year && date.month == month;
    }).toList();

    // 如果没有符合条件的日期，返回 null
    if (filteredDates.isEmpty) {
      return null;
    }

    // 找到最晚的日期
    filteredDates.sort((a, b) => b.compareTo(a)); // 降序排序
    return filteredDates.first; // 返回第一个元素，即最晚的日期
  }
}
