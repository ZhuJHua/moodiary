import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get/get.dart';

import 'calendar_logic.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<CalendarLogic>();
    final state = Bind.find<CalendarLogic>().state;
    final colorScheme = Theme.of(context).colorScheme;
    final i18n = AppLocalizations.of(context)!;
    //生成日历选择器
    Widget buildDatePicker() {
      return Card.filled(
        color: colorScheme.surfaceContainer,
        child: CalendarDatePicker2(
          config: CalendarDatePicker2Config(
            calendarViewMode: CalendarDatePicker2Mode.day,
            calendarType: CalendarDatePicker2Type.single,
          ),
          onValueChanged: (value) {
            state.selectedDate = value;
          },
          value: state.selectedDate,
        ),
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
              sliver: SliverList.list(children: [buildDatePicker()]),
            ),
          ],
        );
      },
    );
  }
}
