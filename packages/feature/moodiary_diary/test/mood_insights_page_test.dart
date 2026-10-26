import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_diary/src/presentation/mood_insights/mood_calendar.dart';
import 'package:moodiary_diary/src/presentation/mood_insights/mood_insights_page.dart';
import 'package:moodiary_diary/src/presentation/mood_insights/mood_patterns.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_entry_tile.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

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
