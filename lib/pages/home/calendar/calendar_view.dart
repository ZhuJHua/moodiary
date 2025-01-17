import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mood_diary/common/values/colors.dart';
import 'package:mood_diary/components/diary_card/calendar_diary_card_view.dart';
import 'package:mood_diary/components/loading/loading.dart';
import 'package:mood_diary/components/time_line/time_line_view.dart';
import 'package:mood_diary/utils/array_util.dart';
import 'package:refreshed/refreshed.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'calendar_logic.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  /// 根据当天日记的数量配置颜色的范围，从0到1
  /// 0为最小值，1为最大值
  /// 当天日记篇数为0时，返回0
  /// 当前日记篇数为5时，返回1，即最大值，保留两位小数
  double getDayColor({required int count}) {
    if (count == 0) {
      return 0;
    }
    if (count >= 5) {
      return 1;
    }
    return count / 5;
  }

  Widget _buildActiveInfo(
      {required Color lessColor,
      required Color moreColor,
      required TextStyle? textStyle}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        spacing: 2.0,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '少',
            style: textStyle,
          ),
          ...List.generate(5, (index) {
            return Container(
              width: 12.0,
              height: 12.0,
              decoration: BoxDecoration(
                color: Color.lerp(lessColor, moreColor, (index + 1) / 5),
                borderRadius: BorderRadius.circular(4.0),
              ),
            );
          }),
          Text(
            '多',
            style: textStyle,
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(CalendarLogic());
    final state = Bind.find<CalendarLogic>().state;
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme;
    final size = MediaQuery.sizeOf(context);

    //生成日历选择器
    Widget buildDatePicker() {
      var dateWithDiaryList = <DateTime>[];
      var allDate = <DateTime>[];
      // 获取有日记的日期，只需要年月日
      for (var diary in state.currentMonthDiaryList) {
        // 如果不存在当前日期，则添加
        var time = diary.time;
        allDate.add(DateTime(time.year, time.month, time.day));
        if (!dateWithDiaryList
            .contains(DateTime(time.year, time.month, time.day))) {
          dateWithDiaryList.add(DateTime(time.year, time.month, time.day));
        }
      }
      final dateCountMap = ArrayUtil.countList(allDate);

      return Stack(
        children: [
          Card.filled(
            color: colorScheme.surfaceContainerLow,
            child: Obx(() {
              return CalendarDatePicker2(
                displayedMonthDate: state.currentMonth.value,
                config: CalendarDatePicker2Config(
                  calendarViewMode: CalendarDatePicker2Mode.day,
                  calendarType: CalendarDatePicker2Type.single,
                  hideMonthPickerDividers: true,
                  hideYearPickerDividers: true,
                  useAbbrLabelForMonthModePicker: true,
                  allowSameValueSelection: true,
                  dayBuilder: ({
                    required DateTime date,
                    TextStyle? textStyle,
                    BoxDecoration? decoration,
                    bool? isSelected,
                    bool? isDisabled,
                    bool? isToday,
                  }) {
                    final contains = dateWithDiaryList.contains(date);
                    final bgColor = contains
                        ? Color.lerp(
                            colorScheme.surfaceContainer,
                            colorScheme.primary,
                            getDayColor(count: dateCountMap[date] ?? 0))
                        : null;
                    return Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: bgColor,
                        ),
                        child: Center(
                          child: Text(
                            date.day.toString(),
                            style: textStyle?.copyWith(
                              color: contains
                                  ? ThemeData.estimateBrightnessForColor(
                                              bgColor!) ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  selectableDayPredicate: (DateTime date) {
                    return dateWithDiaryList.contains(date);
                  },
                ),
                onValueChanged: (value) {
                  logic.animateToSelectedDateWithLock(value.first);
                },
                onDisplayedMonthChanged: (value) async {
                  var lastDate = logic.findLatestDateInMonth(
                      dateWithDiaryList, value.year, value.month);
                  if (lastDate != null) {
                    await logic.animateToSelectedDateWithLock(lastDate);
                  }
                },
                value: const [],
              );
            }),
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: _buildActiveInfo(
                lessColor: colorScheme.surfaceContainer,
                moreColor: colorScheme.primary,
                textStyle: textStyle.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.8))),
          ),
        ],
      );
    }

    Widget buildCardList() {
      return Obx(() {
        return ScrollablePositionedList.builder(
          itemBuilder: (context, index) {
            return TimeLineComponent(
              actionColor: Color.lerp(
                  AppColor.emoColorList.first,
                  AppColor.emoColorList.last,
                  state.currentMonthDiaryList[index].mood)!,
              child: CalendarDiaryCardComponent(
                  diary: state.currentMonthDiaryList[index]),
            );
          },
          itemScrollController: logic.itemScrollController,
          itemPositionsListener: logic.itemPositionsListener,
          scrollOffsetController: logic.scrollOffsetController,
          scrollOffsetListener: logic.scrollOffsetListener,
          itemCount: state.currentMonthDiaryList.length,
        );
      });
    }

    return GetBuilder<CalendarLogic>(
      assignId: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: size.width > 600
                ? Row(
                    children: [
                      Expanded(
                        child: Obx(() {
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: state.isFetching.value
                                ? const Center(
                                    key: ValueKey('processing'),
                                    child: Processing())
                                : (state.currentMonthDiaryList.isNotEmpty
                                    ? buildCardList()
                                    : const Center(
                                        key: ValueKey('empty'),
                                        child: FaIcon(
                                          FontAwesomeIcons.boxOpen,
                                          size: 56,
                                        ),
                                      )),
                          );
                        }),
                      ),
                      Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: 320,
                          child: Obx(() {
                            return buildDatePicker();
                          }),
                        ),
                      ),
                    ],
                  )
                : Column(
                    spacing: 4.0,
                    children: [
                      Obx(() {
                        return buildDatePicker();
                      }),
                      Expanded(child: Obx(() {
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: state.isFetching.value
                              ? const Center(
                                  key: ValueKey('processing'),
                                  child: Processing())
                              : (state.currentMonthDiaryList.isNotEmpty
                                  ? buildCardList()
                                  : Center(
                                      key: const ValueKey('empty'),
                                      child: FaIcon(
                                        FontAwesomeIcons.boxOpen,
                                        color: colorScheme.onSurface,
                                        size: 56,
                                      ),
                                    )),
                        );
                      })),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
