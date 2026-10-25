import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_diary/src/presentation/mood_insights/mood_insights_page.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:mui/mui.dart';

import 'support/pump.dart';

class _Repository implements MoodInsightsRepository {
  List<MoodInsightEntry> rows = [];
  final queries = <({DateTime start, DateTime end})>[];
  @override
  Future<List<MoodInsightEntry>> entries(DateTime start, DateTime end) async {
    queries.add((start: start, end: end));
    return rows
        .where((e) => !e.time.isBefore(start) && e.time.isBefore(end))
        .toList();
  }

  @override
  Future<bool> hasRecordedMood() async => rows.any((e) => e.mood != null);
}

class _Diaries implements DiaryRepository {
  @override
  Stream<DiaryEvent> get diaryEvents => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(setupPluralResolvers);
  late _Repository repository;
  setUp(() {
    repository = _Repository();
    getIt.registerSingleton<MoodInsightsRepository>(repository);
    getIt.registerSingleton<DiaryRepository>(_Diaries());
  });
  tearDown(getIt.reset);

  testWidgets(
    'empty state replaces all data cards and scope navigation still works',
    (tester) async {
      await tester.pumpWidget(
        muiTestApp(const MoodInsightsPage(), wrapScaffold: false),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.insights.empty), findsOneWidget);
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
}
