import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_diary/src/presentation/mood_insights/mood_calendar.dart';
import 'package:moodiary_diary/src/presentation/mood_insights/mood_insights_page.dart';
import 'package:moodiary_diary/src/presentation/mood_insights/mood_patterns.dart';
import 'package:moodiary_diary/src/presentation/mood_insights/mood_period_picker.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_entry_tile.dart';
import 'package:moodiary_diary/src/presentation/widget/today_glyph.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import 'support/pump.dart';

class _Repository implements MoodInsightsRepository {
  Completer<List<MoodInsightEntry>>? pending;
  List<MoodInsightEntry> rows = [];
  final queries = <({DateTime start, DateTime end})>[];
  @override
  Future<List<MoodInsightEntry>> entries(DateTime start, DateTime end) async {
    queries.add((start: start, end: end));
    if (pending case final request?) return request.future;
    return rows
        .where((e) => !e.time.isBefore(start) && e.time.isBefore(end))
        .toList();
  }

  @override
  Future<DateTime?> earliestEntry() async => rows.isEmpty
      ? null
      : rows.map((e) => e.time).reduce((a, b) => a.isBefore(b) ? a : b);

  @override
  Future<bool> hasRecordedMood() async => rows.any((e) => e.mood != null);
}

class _Diaries implements DiaryRepository {
  Completer<List<Diary>>? pending;
  List<Diary> rows = [];
  @override
  Future<List<Diary>> getDiariesByDateRange(
    DateTime start,
    DateTime end, {
    bool visibleOnly = true,
  }) async => pending == null ? rows : pending!.future;
  @override
  Stream<DiaryEvent> get diaryEvents => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(setupPluralResolvers);
  late _Repository repository;
  late _Diaries diaries;
  setUp(() {
    repository = _Repository();
    diaries = _Diaries();
    getIt.registerSingleton<MoodInsightsRepository>(repository);
    getIt.registerSingleton<DiaryRepository>(diaries);
  });
  tearDown(getIt.reset);

  Future<void> openPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = moodDayKey(DateTime.now());
    repository.rows = [
      for (var year = today.year - 2; year <= today.year; year++)
        for (var month = 1; month <= 12; month++)
          if (!DateTime(year, month).isAfter(today))
            MoodInsightEntry(
              id: '$year-$month',
              time: DateTime(year, month),
              mood: month == 1 ? .awful : .great,
            ),
      MoodInsightEntry(id: 'today', time: today, mood: .good),
    ];
    await tester.pumpWidget(
      muiTestApp(const MoodInsightsPage(), wrapScaffold: false),
    );
    await tester.pumpAndSettle();
  }

  final periodButton = find.byKey(const ValueKey('insights-period-picker'));
  Finder cell(DateTime date) =>
      find.byKey(ValueKey('period-${date.year}-${date.month}'));
  Future<void> openPicker(WidgetTester tester) async {
    await tester.ensureVisible(periodButton);
    await tester.tap(periodButton);
    await tester.pumpAndSettle();
  }

  for (final scope in MoodInsightsScope.values) {
    testWidgets('$scope opens its picker and jumps to the selected period', (
      tester,
    ) async {
      await openPage(tester);
      final today = moodDayKey(DateTime.now());
      final scopeLabel = switch (scope) {
        .week => l10n.insights.week,
        .month => l10n.insights.month,
        .year => l10n.insights.year,
      };
      await tester.tap(find.text(scopeLabel));
      await tester.pumpAndSettle();
      await openPicker(tester);
      expect(
        find.text(switch (scope) {
          .week => l10n.insights.selectWeek,
          .month => l10n.insights.selectMonth,
          .year => l10n.insights.selectYear,
        }),
        findsOneWidget,
      );
      final target = switch (scope) {
        .week => DateTime(today.year, today.month),
        .month => DateTime(today.year, 1),
        .year => DateTime(today.year - 1),
      };
      final choice = scope == .week
          ? find.byKey(ValueKey('week-day-${target.year}-${target.month}-1'))
          : cell(target);
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(repository.queries.last.end, moodPeriodBounds(target, scope).end);
      if (scope != .week) {
        expect(
          tester.widget<MoodCalendar>(find.byType(MoodCalendar)).start,
          target,
        );
      }
      if (scope == .month) {
        expect(
          find.text(DateFormat.yMMMM('zh').format(target)),
          findsOneWidget,
        );
        final calendar = tester.widget<MoodCalendar>(find.byType(MoodCalendar));
        expect(calendar.days[target]!.level, DiaryMood.awful);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final scope in [MoodInsightsScope.month, MoodInsightsScope.year]) {
    testWidgets('$scope selected picker label uses onPrimaryContainer', (
      tester,
    ) async {
      await openPage(tester);
      if (scope == .year) {
        await tester.tap(find.text(l10n.insights.year));
        await tester.pumpAndSettle();
      }
      await openPicker(tester);
      final today = moodDayKey(DateTime.now());
      final selected = moodPeriodBounds(today, scope).start;
      final selectedCell = cell(selected);
      final colorScheme = Theme.of(tester.element(selectedCell)).colorScheme;
      final selectedLabel = tester.widget<Text>(
        find.descendant(of: selectedCell, matching: find.byType(Text)),
      );
      expect(selectedLabel.style?.color, colorScheme.onPrimaryContainer);
      final other = scope == .year
          ? DateTime(today.year - 1)
          : DateTime(today.year, today.month == 1 ? 2 : 1);
      final otherLabel = tester.widget<Text>(
        find.descendant(of: cell(other), matching: find.byType(Text)),
      );
      expect(otherLabel.style?.color, colorScheme.onSurface);
    });
  }

  testWidgets('week picker highlighted row numbers use onPrimaryContainer', (
    tester,
  ) async {
    await openPage(tester);
    await tester.tap(find.text(l10n.insights.week));
    await tester.pumpAndSettle();
    await openPicker(tester);
    final today = moodDayKey(DateTime.now());
    final selectedWeek = moodPeriodBounds(today, .week).start;
    Finder dayCell(DateTime day) =>
        find.byKey(ValueKey('week-day-${day.year}-${day.month}-${day.day}'));
    final colorScheme = Theme.of(tester.element(dayCell(today))).colorScheme;
    final month = DateTime(today.year, today.month);
    final firstWeek = moodPeriodBounds(month, .week).start;
    final end = DateTime(today.year, today.month + 1);
    for (
      var week = firstWeek;
      week.isBefore(end);
      week = moodDayOffset(week, 7)
    ) {
      for (var i = 0; i < 7; i++) {
        final number = tester.widget<Text>(
          find.descendant(
            of: dayCell(moodDayOffset(week, i)),
            matching: find.byType(Text),
          ),
        );
        expect(
          number.style?.color,
          week == selectedWeek
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurface,
        );
      }
    }
  });

  testWidgets('month picker bounds, selection style and averages', (
    tester,
  ) async {
    await openPage(tester);
    final today = moodDayKey(DateTime.now());
    await openPicker(tester);
    final current = cell(DateTime(today.year, today.month));
    final selectedBox =
        tester
                .widget<Container>(
                  find
                      .descendant(of: current, matching: find.byType(Container))
                      .first,
                )
                .decoration!
            as BoxDecoration;
    expect(selectedBox.border!.top.width, 1.5);
    for (var month = today.month + 1; month <= 12; month++) {
      final future = cell(DateTime(today.year, month));
      expect(tester.widget<MInkWell>(future).onTap, isNull);
      await tester.tap(future);
      expect(find.byType(BottomSheet), findsOneWidget);
    }
    final january = cell(DateTime(today.year));
    expect(
      tester
          .widget<MoodGlyph>(
            find.descendant(of: january, matching: find.byType(MoodGlyph)),
          )
          .mood,
      today.month == 1 ? DiaryMood.okay : DiaryMood.awful,
    );
    IconButton navigation(String label) => tester.widget<IconButton>(
      find
          .ancestor(
            of: find.descendant(
              of: find.byType(BottomSheet),
              matching: find.byTooltip(label),
            ),
            matching: find.byType(IconButton),
          )
          .first,
    );
    expect(navigation(l10n.insights.nextPeriod).onPressed, isNull);
    for (var i = 0; i < 2; i++) {
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byTooltip(l10n.insights.previousPeriod),
        ),
      );
      await tester.pumpAndSettle();
    }
    expect(navigation(l10n.insights.previousPeriod).onPressed, isNull);
    expect(cell(DateTime(today.year - 2)), findsOneWidget);
  });

  testWidgets('year picker uses the same full-year mean as the summary', (
    tester,
  ) async {
    final today = moodDayKey(DateTime.now());
    repository.rows = [
      MoodInsightEntry(
        id: 'end-of-year',
        time: DateTime(today.year, 12, 31),
        mood: .awful,
      ),
    ];
    await tester.pumpWidget(
      muiTestApp(const MoodInsightsPage(), wrapScaffold: false),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.insights.year));
    await tester.pumpAndSettle();
    await openPicker(tester);
    expect(
      tester
          .widget<MoodGlyph>(
            find.descendant(
              of: cell(DateTime(today.year)),
              matching: find.byType(MoodGlyph),
            ),
          )
          .mood,
      DiaryMood.awful,
    );
  });

  testWidgets('future-only diaries still allow choosing the current year', (
    tester,
  ) async {
    final today = moodDayKey(DateTime.now());
    repository.rows = [
      MoodInsightEntry(
        id: 'future',
        time: DateTime(today.year + 1),
        mood: .good,
      ),
    ];
    await tester.pumpWidget(
      muiTestApp(const MoodInsightsPage(), wrapScaffold: false),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.insights.year));
    await tester.pumpAndSettle();
    await openPicker(tester);
    final current = cell(DateTime(today.year));
    expect(tester.widget<MInkWell>(current).onTap, isNotNull);
    expect(
      find.descendant(of: current, matching: find.byType(MoodGlyph)),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  for (final column in [0, 3, 6]) {
    testWidgets('tapping weekday area $column selects the whole week', (
      tester,
    ) async {
      await openPage(tester);
      await tester.tap(find.text(l10n.insights.week));
      await tester.pumpAndSettle();
      await openPicker(tester);
      final today = moodDayKey(DateTime.now());
      final week = moodPeriodBounds(
        DateTime(today.year, today.month),
        .week,
      ).start;
      final day = moodDayOffset(week, column);
      final row = find.byKey(
        ValueKey('week-row-${week.year}-${week.month}-${week.day}'),
      );
      final ink = find.descendant(of: row, matching: find.byType(MInkWell));
      expect(ink, findsOneWidget);
      expect(tester.getSize(ink).width, tester.getSize(row).width);
      expect(
        tester.widget<MInkWell>(ink).borderRadius,
        BorderRadius.circular(12),
      );
      final dayArea = find.byKey(
        ValueKey('week-day-${day.year}-${day.month}-${day.day}'),
      );
      expect(
        find.descendant(of: dayArea, matching: find.byType(MInkWell)),
        findsNothing,
      );
      await tester.tap(dayArea);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(repository.queries.last.end, moodDayOffset(week, 7));
    });
  }

  testWidgets('today row stays enabled including its dimmed future day areas', (
    tester,
  ) async {
    await openPage(tester);
    await tester.tap(find.text(l10n.insights.week));
    await tester.pumpAndSettle();
    await openPicker(tester);
    final today = moodDayKey(DateTime.now());
    final week = moodPeriodBounds(today, .week).start;
    final row = find.byKey(
      ValueKey('week-row-${week.year}-${week.month}-${week.day}'),
    );
    final ink = tester.widget<MInkWell>(
      find.descendant(of: row, matching: find.byType(MInkWell)),
    );
    expect(ink.enabled, isTrue);
    expect(ink.onTap, isNotNull);
    final highlight = tester.widget<DecoratedBox>(
      find.descendant(of: row, matching: find.byType(DecoratedBox)),
    );
    expect(
      (highlight.decoration as BoxDecoration).color,
      Theme.of(tester.element(row)).colorScheme.primaryContainer,
    );
    final tomorrow = moodDayOffset(today, 1);
    final target = tomorrow.isBefore(moodDayOffset(week, 7)) ? tomorrow : today;
    final dayArea = find.byKey(
      ValueKey('week-day-${target.year}-${target.month}-${target.day}'),
    );
    expect(
      tester
          .widget<Opacity>(
            find.descendant(of: dayArea, matching: find.byType(Opacity)),
          )
          .opacity,
      target == today ? 1 : .38,
    );
    await tester.tap(dayArea);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(repository.queries.last.end, moodDayOffset(week, 7));
  });

  testWidgets('entirely future week row is disabled and dimmed only once', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final today = moodDayKey(DateTime.now());
      final month = DateTime(today.year, today.month + 1);
      final week = moodPeriodBounds(moodDayOffset(month, 6), .week).start;
      await tester.pumpWidget(
        muiTestApp(
          MoodPeriodPicker(scope: .week, anchor: month, repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      final row = find.byKey(
        ValueKey('week-row-${week.year}-${week.month}-${week.day}'),
      );
      final ink = tester.widget<MInkWell>(
        find.descendant(of: row, matching: find.byType(MInkWell)),
      );
      expect(ink.enabled, isFalse);
      expect(ink.onTap, isNull);
      expect(
        tester
            .widget<Opacity>(
              find.descendant(of: row, matching: find.byType(Opacity)).first,
            )
            .opacity,
        .38,
      );
      final dayOpacities = tester
          .widgetList<Opacity>(
            find.descendant(of: row, matching: find.byType(Opacity)),
          )
          .skip(1);
      expect(dayOpacities.map((w) => w.opacity), everyElement(1.0));
      final node = tester.getSemantics(row);
      expect(
        node,
        matchesSemantics(
          label: node.label,
          isButton: true,
          hasEnabledState: true,
          hasSelectedState: true,
          isSelected: week == moodPeriodBounds(month, .week).start,
        ),
      );
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(row, findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  for (final (locale, range) in [
    (const Locale('zh'), '10月11日 – 10月17日'),
    (const Locale('en'), 'Oct 11 – Oct 17'),
  ]) {
    testWidgets('week rows expose one localized button each in $locale', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        final anchor = DateTime(2026, 10, 11);
        await tester.pumpWidget(
          muiTestApp(
            MoodPeriodPicker(
              scope: .week,
              anchor: anchor,
              repository: repository,
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        final start = moodPeriodBounds(DateTime(2026, 10), .week).start;
        var rows = 0;
        final ids = <int>{};
        for (
          var week = start;
          week.isBefore(DateTime(2026, 11));
          week = moodDayOffset(week, 7)
        ) {
          final row = find.byKey(
            ValueKey('week-row-${week.year}-${week.month}-${week.day}'),
          );
          final node = tester.getSemantics(row);
          final enabled = !week.isAfter(moodDayKey(DateTime.now()));
          expect(
            node,
            matchesSemantics(
              label: week == anchor ? range : node.label,
              isButton: true,
              hasSelectedState: true,
              isSelected: week == anchor,
              hasEnabledState: true,
              isEnabled: enabled,
              hasTapAction: enabled,
            ),
          );
          expect(node.childrenCount, 0);
          expect(find.bySemanticsLabel(node.label), findsOneWidget);
          ids.add(node.id);
          rows++;
        }
        expect(rows, 5);
        expect(ids.length, rows);
        expect(find.byType(MInkWell), findsNWidgets(rows));
      } finally {
        semantics.dispose();
      }
    });
  }

  for (final scope in MoodInsightsScope.values) {
    testWidgets('back to today is conditional and returns to current $scope', (
      tester,
    ) async {
      await openPage(tester);
      await tester.tap(
        find.text(switch (scope) {
          .week => l10n.insights.week,
          .month => l10n.insights.month,
          .year => l10n.insights.year,
        }),
      );
      await tester.pumpAndSettle();
      final todayAction = find.byTooltip(l10n.diary.calendarBackToToday);
      expect(todayAction, findsNothing);
      await tester.tap(find.byTooltip(l10n.insights.previousPeriod));
      await tester.pumpAndSettle();
      expect(todayAction, findsOneWidget);
      expect(
        tester.widget<TodayGlyph>(find.byType(TodayGlyph)).day,
        DateTime.now().day,
      );
      await tester.tap(todayAction);
      await tester.pumpAndSettle();
      expect(todayAction, findsNothing);
      expect(
        repository.queries.last.end,
        moodPeriodBounds(DateTime.now(), scope).end,
      );
    });
  }

  testWidgets('flings navigate but chart scrubbing and slow drags do not', (
    tester,
  ) async {
    await openPage(tester);
    final currentEnd = repository.queries.last.end;
    await tester.timedDrag(
      periodButton,
      const Offset(100, 0),
      const Duration(seconds: 2),
    );
    await tester.pumpAndSettle();
    expect(repository.queries.last.end, currentEnd);
    await tester.fling(periodButton, const Offset(200, 0), 800);
    await tester.pumpAndSettle();
    expect(
      repository.queries.last.end,
      DateTime(currentEnd.year, currentEnd.month - 1),
    );
    final previousEnd = repository.queries.last.end;
    await tester.ensureVisible(find.byType(MLineChart));
    await tester.pumpAndSettle();
    final chart = tester.getRect(find.byType(MLineChart));
    await tester.flingFrom(
      chart.centerLeft + const Offset(45, 80),
      const Offset(150, 0),
      800,
    );
    await tester.pumpAndSettle();
    expect(repository.queries.last.end, previousEnd);
    expect(find.byKey(const ValueKey('line-chart-tooltip')), findsOneWidget);
    await tester.scrollUntilVisible(
      periodButton,
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.fling(periodButton, const Offset(-200, 0), 800);
    await tester.pumpAndSettle();
    expect(repository.queries.last.end, currentEnd);
    final count = repository.queries.length;
    await tester.fling(periodButton, const Offset(-200, 0), 800);
    await tester.pumpAndSettle();
    expect(repository.queries.length, count);
  });

  testWidgets('picker jump shows skeleton until new period finishes loading', (
    tester,
  ) async {
    await openPage(tester);
    await openPicker(tester);
    final target = DateTime(DateTime.now().year, 1);
    repository.pending = Completer();
    await tester.tap(cell(target));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.widget<MSkeleton>(find.byType(MSkeleton)).enabled, isTrue);
    expect(
      tester.widget<MoodCalendar>(find.byType(MoodCalendar)).start,
      target,
    );
    repository.pending!.complete([
      MoodInsightEntry(id: 'jumped', time: target, mood: .awful),
    ]);
    await tester.pumpAndSettle();
    expect(tester.widget<MSkeleton>(find.byType(MSkeleton)).enabled, isFalse);
    expect(
      tester
          .widget<MoodCalendar>(find.byType(MoodCalendar))
          .days[target]!
          .level,
      DiaryMood.awful,
    );
  });

  for (final month in [1, 2]) {
    testWidgets('year row $month drills down including an unlabelled row', (
      tester,
    ) async {
      await openPage(tester);
      await tester.tap(find.text(l10n.insights.year));
      await tester.pumpAndSettle();
      // Use a past year to exercise all months without future dates.
      await tester.tap(find.byTooltip(l10n.insights.previousPeriod));
      await tester.pumpAndSettle();
      final label = find.byKey(ValueKey('insights-year-month-$month'));
      await tester.ensureVisible(label);
      await tester.tap(label);
      await tester.pumpAndSettle();
      final calendar = tester.widget<MoodCalendar>(find.byType(MoodCalendar));
      expect(calendar.scope, MoodInsightsScope.month);
      expect(calendar.start, DateTime(DateTime.now().year - 1, month));
      await tester.scrollUntilVisible(
        periodButton,
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<MSegmentedControl<MoodInsightsScope>>(
              find.byType(MSegmentedControl<MoodInsightsScope>),
            )
            .selected,
        MoodInsightsScope.month,
      );
    });
  }

  for (final scope in MoodInsightsScope.values) {
    testWidgets('$scope pending period uses the normal layout with bones', (
      tester,
    ) async {
      repository.pending = Completer();
      await tester.pumpWidget(
        muiTestApp(const MoodInsightsPage(), wrapScaffold: false),
      );
      if (scope != .month) {
        await tester.tap(
          find.text(scope == .week ? l10n.insights.week : l10n.insights.year),
        );
        await tester.pump();
      }
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final skeleton = find.byType(MSkeleton);
      expect(tester.widget<MSkeleton>(skeleton).enabled, isTrue);
      expect(
        find.ancestor(
          of: find.byType(MSegmentedControl<MoodInsightsScope>),
          matching: skeleton,
        ),
        findsNothing,
      );
      expect(
        find.byType(MoodCalendar),
        scope == .week ? findsNothing : findsOneWidget,
      );
      expect(find.byWidgetPredicate((w) => w is Bone), findsWidgets);
      // Controls remain usable during the request and keep the chosen scope.
      await tester.tap(find.byTooltip(l10n.insights.previousPeriod));
      await tester.pump();
      final bounds = repository.queries.last;
      final chartSize = tester.getSize(find.byType(MLineChart));
      final calendarSize = scope == .week
          ? null
          : tester.getSize(find.byType(MoodCalendar));
      repository.pending!.complete([
        MoodInsightEntry(
          id: 'loaded',
          time: moodDayOffset(bounds.end, -1),
          mood: .good,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(tester.widget<MSkeleton>(find.byType(MSkeleton)).enabled, isFalse);
      expect(find.byWidgetPredicate((w) => w is Bone), findsNothing);
      expect(find.text('4.0'), findsOneWidget);
      expect(tester.getSize(find.byType(MLineChart)), chartSize);
      if (scope != .week) {
        final calendar = tester.widget<MoodCalendar>(find.byType(MoodCalendar));
        expect(calendar.scope, scope);
        expect(tester.getSize(find.byType(MoodCalendar)), calendarSize);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final scope in [MoodInsightsScope.month, MoodInsightsScope.year]) {
    testWidgets('$scope cells replace mood colors with uniform bones', (
      tester,
    ) async {
      final start = DateTime(2026, 10);
      final day = MoodInsightDay([
        MoodInsightEntry(id: 'a', time: start, mood: .great),
      ]);
      await tester.pumpWidget(
        muiTestApp(
          MSkeleton(
            enabled: true,
            child: MoodCalendar(
              scope: scope,
              start: start,
              days: {start: day},
              selected: start,
              onSelected: (_) {},
            ),
          ),
        ),
      );
      final calendar = find.byType(MoodCalendar);
      expect(
        find.descendant(of: calendar, matching: find.byType(MInkWell)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: calendar,
          matching: find.byWidgetPredicate((w) => w is Bone),
        ),
        findsNWidgets(scope == .month ? 31 : 365),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pending day sheet shows two real entry tiles as skeleton rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = moodDayKey(DateTime.now());
    repository.rows = [MoodInsightEntry(id: 'today', time: today, mood: .good)];
    diaries.pending = Completer();
    await tester.pumpWidget(
      muiTestApp(const MoodInsightsPage(), wrapScaffold: false),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(MoodCalendar),
        matching: find.text('${today.day}'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(l10n.insights.view));
    await tester.tap(find.text(l10n.insights.view));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(DiaryEntryTile), findsNWidgets(2));
    expect(
      tester.widget<MSkeleton>(find.byType(MSkeleton).last).enabled,
      isTrue,
    );
    diaries.pending!.complete([
      Diary.empty(type: .richText).copyWith(title: 'Loaded day diary'),
    ]);
    await tester.pumpAndSettle();
    expect(find.byType(DiaryEntryTile), findsOneWidget);
    expect(find.text('Loaded day diary'), findsOneWidget);
    expect(
      tester.widget<MSkeleton>(find.byType(MSkeleton).last).enabled,
      isFalse,
    );
  });

  testWidgets(
    'empty state replaces all data cards and scope navigation still works',
    (tester) async {
      await tester.pumpWidget(
        muiTestApp(const MoodInsightsPage(), wrapScaffold: false),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.insights.empty), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(MSegmentedControl<MoodInsightsScope>),
          matching: find.byType(Card),
        ),
        findsNothing,
      );
      expect(find.byType(MLineChart), findsNothing);
      expect(find.text(l10n.insights.calendar), findsNothing);
      await tester.tap(find.text(l10n.insights.week));
      await tester.pumpAndSettle();
      expect(find.text(l10n.insights.empty), findsOneWidget);
      final bounds = moodPeriodBounds(DateTime.now(), .week);
      expect(repository.queries.last.end, bounds.end);
      await tester.tap(find.text(l10n.insights.year));
      await tester.pumpAndSettle();
      expect(repository.queries.last.end, DateTime(DateTime.now().year + 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'default month, week and year show their respective data blocks',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now();
      repository.rows = [
        MoodInsightEntry(
          id: 'today',
          time: moodDayKey(now),
          mood: DiaryMood.good,
          title: 'Today entry',
        ),
      ];
      await tester.pumpWidget(
        muiTestApp(const MoodInsightsPage(), wrapScaffold: false),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.insights.calendar), findsOneWidget);
      expect(find.text(l10n.insights.streakDays(count: 1)), findsOneWidget);
      expect(find.text(l10n.insights.streak), findsOneWidget);
      expect(find.text(l10n.insights.empty), findsNothing);
      final next = tester.widget<IconButton>(
        find
            .ancestor(
              of: find.byTooltip(l10n.insights.nextPeriod),
              matching: find.byType(IconButton),
            )
            .first,
      );
      expect(next.onPressed, isNull);
      await tester.tap(find.text(l10n.insights.week));
      await tester.pumpAndSettle();
      expect(find.text(l10n.insights.calendar), findsNothing);
      await tester.scrollUntilVisible(
        find.text(l10n.insights.weekDiaries),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l10n.insights.weekDiaries), findsOneWidget);
      expect(
        find.text(
          l10n.insights.dayHeader(
            date: TimeFormat.monthDay(moodDayKey(now)),
            weekday: l10n.insights.today,
          ),
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text(l10n.insights.year),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(l10n.insights.year));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(l10n.insights.yearPixels),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l10n.insights.yearPixels), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final count in [1, 20]) {
    testWidgets('day sheet wraps $count entries and dismisses by dragging', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final today = moodDayKey(DateTime.now());
      repository.rows = [
        MoodInsightEntry(id: 'today', time: today, mood: DiaryMood.good),
      ];
      diaries.rows = [
        for (var i = 0; i < count; i++)
          Diary(
            id: '$i',
            title: 'Entry $i',
            content: '',
            contentText: 'Body',
            time: today,
            lastModified: today,
            show: true,
            imageName: const [],
            audioName: const [],
            videoName: const [],
            tags: const [],
            type: DiaryType.tiptap.value,
          ),
      ];
      await tester.pumpWidget(
        muiTestApp(const MoodInsightsPage(), wrapScaffold: false),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(MoodCalendar),
          matching: find.text('${today.day}'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(l10n.insights.view));
      await tester.tap(find.text(l10n.insights.view));
      await tester.pumpAndSettle();
      final list = find.byType(ListView).last;
      final scrollable = find
          .descendant(of: list, matching: find.byType(Scrollable))
          .first;
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(tester.getSize(list).height, lessThanOrEqualTo(844 * .75));
      if (count == 1) {
        expect(tester.getSize(list).height, lessThan(300));
        expect(position.maxScrollExtent, 0);
        expect(position.physics.shouldAcceptUserOffset(position), isFalse);
        await tester.drag(
          find.byType(DiaryEntryTile).first,
          const Offset(0, 300),
        );
      } else {
        expect(position.maxScrollExtent, greaterThan(0));
        await tester.scrollUntilVisible(
          find.text('Entry 19'),
          300,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        expect(find.text('Entry 19').hitTestable(), findsOneWidget);
        // The handle remains available while the content scrolls.
        final top = tester.getTopLeft(list);
        await tester.dragFrom(Offset(195, top.dy - 24), const Offset(0, 600));
      }
      await tester.pumpAndSettle();
      expect(find.byType(DiaryEntryTile), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final (locale, labels) in [
    (const Locale('zh'), ['1月', '4月', '7月', '10月']),
    (const Locale('en'), ['Jan', 'Apr', 'Jul', 'Oct']),
  ]) {
    testWidgets('year month labels are centred and unclipped in $locale', (
      tester,
    ) async {
      await tester.pumpWidget(
        muiTestApp(
          Center(
            child: SizedBox(
              width: 320,
              child: MoodCalendar(
                scope: .year,
                start: DateTime(2026),
                days: const {},
                selected: null,
                onSelected: (_) {},
              ),
            ),
          ),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();
      final calendar = tester.getRect(find.byType(MoodCalendar));
      final pixels = find.descendant(
        of: find.byType(MoodCalendar),
        matching: find.byType(MInkWell),
      );
      for (var i = 0; i < labels.length; i++) {
        final label = tester.getRect(find.text(labels[i]));
        final dayIndex = DateTime(
          2026,
          1 + i * 3,
        ).difference(DateTime(2026)).inDays;
        final pixel = tester.getRect(pixels.at(dayIndex));
        expect(label.center.dy, closeTo(pixel.center.dy, .01));
        expect(label.top, greaterThanOrEqualTo(calendar.top));
        expect(label.bottom, lessThanOrEqualTo(calendar.bottom));
        expect(label.right, lessThan(pixel.left));
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final (values, heights) in [
    ([5.0, 2.5], [40.0, 10.0]),
    ([3.5, 2.5], [20.0, 20.0]),
  ]) {
    testWidgets(
      'weekday bars scale to $values without covering the baseline label',
      (tester) async {
        await tester.pumpWidget(
          muiTestApp(
            ListView(
              children: [
                MoodWeekdayPattern(
                  averages: [...values, null, null, null, null, null],
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        final bars = find.byWidgetPredicate(
          (widget) => widget is Container && widget.constraints?.maxWidth == 18,
        );
        expect(bars, findsNWidgets(2));
        final label = tester.getRect(find.text('3.0'));
        for (var i = 0; i < heights.length; i++) {
          final bar = tester.getRect(bars.at(i));
          expect(bar.height, heights[i]);
          expect(label.right, lessThan(bar.left));
        }
        expect(
          tester.getSize(find.byType(MoodWeekdayPattern)).height,
          lessThan(120),
        );
      },
    );
  }
}
