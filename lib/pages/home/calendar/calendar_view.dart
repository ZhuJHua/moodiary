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
                            dayTextStylePredicate: ({required date}) {
                              return state.dateHasDiary.any((dateTime) =>
                                      dateTime.year == date.year &&
                                      dateTime.month == date.month &&
                                      dateTime.day == date.day)
                                  ? TextStyle(
                                      color: colorScheme.primary,
                                    )
                                  : null;
                            }),
                        onValueChanged: (value) async {
                          await logic.updateDate(value.first);
                        },
                        onDisplayedMonthChanged: (value) async {
                          await logic.getDateHasDiary(value);
                        },
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
      return SliverList.builder(
        itemBuilder: (context, index) {
          return TimeLineComponent(
            actionColor:
                Color.lerp(AppColor.emoColorList.first, AppColor.emoColorList.last, state.diaryList[index].mood)!,
            child: CalendarDiaryCardComponent(diary: state.diaryList[index]),
          );
        },
        itemCount: state.diaryList.length,
      );
    }

    return GetBuilder<CalendarLogic>(
      assignId: true,
      builder: (_) {
        return CustomScrollView(
          slivers: [
            SliverAppBar(
              title: Text(i18n.homeNavigatorCalendar),
              actions: [
                IconButton(
                    onPressed: () async {
                      await logic.backToToday();
                    },
                    icon: const Icon(Icons.today))
              ],
            ),
            SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                sliver: SliverToBoxAdapter(
                  child: buildDatePicker(),
                )),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              sliver: Obx(() {
                return buildCardList();
              }),
            )
          ],
        );
      },
    );
  }
}
