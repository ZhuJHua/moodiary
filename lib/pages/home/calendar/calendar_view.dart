import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mood_diary/common/values/border.dart';
import 'package:mood_diary/common/values/colors.dart';
import 'package:mood_diary/components/diary_card/calendar_diary_card/calendar_diary_card_view.dart';
import 'package:mood_diary/components/time_line/time_line_view.dart';

import 'calendar_logic.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(CalendarLogic());
    final state = Bind.find<CalendarLogic>().state;
    final colorScheme = Theme.of(context).colorScheme;
    final i18n = AppLocalizations.of(context)!;

    //生成日历选择器
    Widget buildDatePicker() {
      final diaryList = state.currentMonthDiaryMap.keys.toList();
      var dateWithDiaryList = <DateTime>[];
      // 获取有日记的日期，只需要年月日
      for (var diary in diaryList) {
        // 如果不存在当前日期，则添加
        var time = diary.time;
        if (!dateWithDiaryList.contains(DateTime(time.year, time.month, time.day))) {
          dateWithDiaryList.add(DateTime(time.year, time.month, time.day));
        }
      }

      return Obx(() {
        return Padding(
          padding: const EdgeInsets.all(4.0),
          child: ClipRRect(
            borderRadius: AppBorderRadius.mediumBorderRadius,
            child: ExpansionPanelList(
              expansionCallback: (index, isExpanded) {
                logic.open(isExpanded);
              },
              children: [
                ExpansionPanel(
                    headerBuilder: (context, isExpanded) {
                      return ListTile(
                        title: Text(DateFormat.yMMMd().format(state.selectedDate.value)),
                      );
                    },
                    backgroundColor: colorScheme.surfaceContainer,
                    body: Obx(() {
                      return CalendarDatePicker2(
                        displayedMonthDate: state.currentMonth.value,
                        config: CalendarDatePicker2Config(
                            calendarViewMode: CalendarDatePicker2Mode.day,
                            calendarType: CalendarDatePicker2Type.single,
                            allowSameValueSelection: true,
                            dayTextStylePredicate: ({required date}) {
                              return dateWithDiaryList.any((dateTime) =>
                                      dateTime.year == date.year &&
                                      dateTime.month == date.month &&
                                      dateTime.day == date.day)
                                  ? TextStyle(
                                      color: colorScheme.primary,
                                    )
                                  : null;
                            }),
                        onValueChanged: (value) async {
                          await logic.animateToSelectedDate(value.first);
                        },
                        onDisplayedMonthChanged: logic.getMonthDiary,
                        value: [state.selectedDate.value],
                      );
                    }),
                    isExpanded: state.isExpanded.value)
              ],
              expandedHeaderPadding: const EdgeInsets.all(8.0),
              elevation: .0,
            ),
          ),
        );
      });
    }

    Widget buildCardList() {
      // 日记列表
      final diaryList = state.currentMonthDiaryMap.keys.toList();
      // globalKey列表
      final keyList = state.currentMonthDiaryMap.values.toList();
      return SliverList.builder(
        itemBuilder: (context, index) {
          return TimeLineComponent(
            key: keyList[index],
            actionColor: Color.lerp(AppColor.emoColorList.first, AppColor.emoColorList.last, diaryList[index].mood)!,
            child: CalendarDiaryCardComponent(diary: diaryList[index]),
          );
        },
        itemCount: diaryList.length,
      );
    }

    return GetBuilder<CalendarLogic>(
      assignId: true,
      builder: (_) {
        return CustomScrollView(
          slivers: [
            SliverAppBar(
              title: Text(i18n.homeNavigatorCalendar),
              actions: [IconButton(onPressed: () async {}, icon: const Icon(Icons.today))],
            ),
            SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                sliver: SliverToBoxAdapter(
                  child: buildDatePicker(),
                )),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              sliver: Obx(() {
                return state.isFetching.value
                    ? const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    : buildCardList();
              }),
            )
          ],
        );
      },
    );
  }
}
