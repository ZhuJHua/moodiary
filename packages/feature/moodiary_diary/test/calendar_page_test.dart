import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary/src/presentation/calendar/calendar_page.dart';
import 'package:moodiary_diary/src/presentation/widget/today_glyph.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

import 'support/pump.dart';

class _Dashboard extends DashboardController {
  @override
  Future<DashboardStats> build() async => const DashboardStats(
    journalDays: 0,
    diaryCount: 0,
    wordCount: 0,
    categoryCount: 0,
    streakDays: 0,
    thisMonthCount: 0,
    tagCount: 0,
    byDay: {},
    lastYearCount: 0,
  );
}

void main() {
  setUpAll(setupPluralResolvers);

  testWidgets('calendar today glyph follows selection and returns to today', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      muiTestApp(
        const CalendarPage(),
        wrapScaffold: false,
        overrides: [dashboardControllerProvider.overrideWith(_Dashboard.new)],
      ),
    );
    await tester.pumpAndSettle();
    final today = DateTime.now();
    final other = today.day == 1 ? 2 : 1;
    expect(tester.widget<TodayGlyph>(find.byType(TodayGlyph)).day, today.day);
    expect(tester.getSize(find.byType(TodayGlyph)), const Size(24, 24));
    await tester.tap(find.text('$other').hitTestable().first);
    await tester.pumpAndSettle();
    expect(tester.widget<TodayGlyph>(find.byType(TodayGlyph)).day, other);
    await tester.tap(find.byTooltip(l10n.diary.calendarBackToToday));
    await tester.pumpAndSettle();
    expect(tester.widget<TodayGlyph>(find.byType(TodayGlyph)).day, today.day);
    await tester.tap(find.byTooltip(l10n.diary.calendarYearView));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l10n.diary.calendarBackToToday));
    await tester.pumpAndSettle();
    expect(tester.widget<TodayGlyph>(find.byType(TodayGlyph)).day, today.day);
    expect(tester.takeException(), isNull);
  });
}
