import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/border.dart';
import 'package:mood_diary/common/values/colors.dart';
import 'package:mood_diary/components/diary_card/calendar_diary_card/calendar_diary_card_view.dart';
import 'package:mood_diary/components/loading/loading.dart';
import 'package:mood_diary/components/time_line/time_line_view.dart';
import 'package:mood_diary/utils/array_util.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../main.dart';
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

      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: ExpansionTile(
            title: Text(l10n.homeNavigatorCalendar),
            initiallyExpanded: true,
            collapsedShape: const RoundedRectangleBorder(
                borderRadius: AppBorderRadius.mediumBorderRadius),
            shape: const RoundedRectangleBorder(
                borderRadius: AppBorderRadius.mediumBorderRadius),
            backgroundColor: colorScheme.surfaceContainer,
            collapsedBackgroundColor: colorScheme.surfaceContainerLow,
            controller: logic.expansionTileController,
            children: [
              Stack(
                children: [
                  Obx(() {
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
                      onDisplayedMonthChanged: logic.getMonthDiary,
                      value: const [],
                    );
                  }),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: _buildActiveInfo(
                        lessColor: colorScheme.surfaceContainer,
                        moreColor: colorScheme.primary,
                        textStyle: textStyle.labelSmall),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    Widget buildCardList() {
      double lastScrollOffset = 0.0;
      return NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          if (notification is ScrollUpdateNotification) {
            const double baseThreshold = 200.0; // 基础阈值
            final double scrollDelta =
                notification.scrollDelta ?? 0.0; // 滚动增量（速度）

            // 根据速度动态调整阈值，速度越快，阈值越高
            final double dynamicThreshold =
                baseThreshold + (scrollDelta.abs() / 2);

            final currentOffset = notification.metrics.pixels;
            final distance = (currentOffset - lastScrollOffset).abs(); // 滚动距离

            if (distance > dynamicThreshold) {
              if (currentOffset > lastScrollOffset) {
                // 向下滚动
                if (!state.isControllerScrolling.value) logic.open(false);
              } else if (currentOffset < lastScrollOffset) {
                // 向上滚动
                if (!state.isControllerScrolling.value) logic.open(true);
              }
              lastScrollOffset = currentOffset; // 更新滚动位置
            }
          }
          return true;
        },
        child: Obx(() {
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
        }),
      );
    }

    return GetBuilder<CalendarLogic>(
      assignId: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Column(
              spacing: 4.0,
              children: [
                Obx(() {
                  return buildDatePicker();
                }),
                Expanded(child: Obx(() {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: state.isFetching.value
                        ? const Center(
                            key: ValueKey('processing'), child: Processing())
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
                })),
              ],
            ),
          ),
        );
      },
    );
  }
}
