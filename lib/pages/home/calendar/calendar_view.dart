import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/colors.dart';
import 'package:mood_diary/components/diary_card/calendar_diary_card/calendar_diary_card_view.dart';
import 'package:mood_diary/components/time_line/time_line_view.dart';

import 'calendar_logic.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<CalendarLogic>();
    final state = Bind.find<CalendarLogic>().state;
    final colorScheme = Theme.of(context).colorScheme;
    final i18n = AppLocalizations.of(context)!;

    Widget buildPlaceHolder() {
      return Center(
        child: Obx(() {
          if (state.isFetching.value) {
            return const CircularProgressIndicator();
          } else if (state.diaryList.isEmpty) {
            return const Icon(Icons.inbox);
          } else {
            return const SizedBox.shrink();
          }
        }),
      );
    }

    //生成日历选择器
    Widget buildDatePicker() {
      return Card.filled(
        color: colorScheme.surfaceContainer,
        child: CalendarDatePicker2(
          config: CalendarDatePicker2Config(
            calendarViewMode: CalendarDatePicker2Mode.day,
            calendarType: CalendarDatePicker2Type.single,
          ),
          onValueChanged: (value) async {
            await logic.updateDate(value);
          },
          value: state.selectedDate,
        ),
      );
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
      init: logic,
      assignId: true,
      builder: (logic) {
        return CustomScrollView(
          slivers: [
            SliverAppBar(
              title: Text(i18n.homeNavigatorCalendar),
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
