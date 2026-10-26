import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_mobile/app/me/me_page.dart';
import 'package:moodiary_mobile/app/me/mood_insights_card.dart';
import 'package:moodiary_mobile/app/shell/mood_upgrade_notice.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';

class _PendingMoods implements MoodInsightsRepository {
  final pending = Completer<List<MoodInsightEntry>>();
  bool recorded = false;

  @override
  Future<List<MoodInsightEntry>> entries(DateTime start, DateTime end) =>
      pending.future;

  @override
  Future<DateTime?> earliestEntry() async => null;

  @override
  Future<bool> hasRecordedMood() async => recorded;
}

class _Diaries implements DiaryRepository {
  @override
  Stream<DiaryEvent> get diaryEvents => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailedMoods extends MoodInsightsController {
  @override
  Future<MoodInsightsCardData> build() async => throw StateError('unavailable');
}

class _Dashboard extends DashboardController {
  @override
  Future<DashboardStats> build() => Completer<DashboardStats>().future;
}

class _ReadyDashboard extends DashboardController {
  static DateTime get today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  Future<DashboardStats> build() async => DashboardStats(
    journalDays: 1,
    diaryCount: 2,
    wordCount: 300,
    categoryCount: 0,
    streakDays: 1,
    thisMonthCount: 2,
    tagCount: 0,
    lastYearCount: 2,
    byDay: {
      today: const DayWriting(
        count: 2,
        words: 300,
        level: 3,
        ids: ['a', 'b'],
        coverName: null,
        coverIsVideo: false,
        categoryId: null,
        title: 'Today',
      ),
    },
  );
}

class _Places extends PlaceController {
  @override
  Future<List<Place>> build() async => [];
}

GoRouter _host(Widget child) => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => Scaffold(body: child),
    ),
    GoRoute(
      path: MoodInsightsRoute.path,
      builder: (_, _) => const Scaffold(body: Text('insights-destination')),
    ),
  ],
);

Widget _app(GoRouter router) => TranslationProvider(
  child: MaterialApp.router(
    theme: buildMuiTheme(brightness: .light),
    routerConfig: router,
    locale: const Locale('zh'),
    supportedLocales: AppLocaleUtils.supportedLocales,
    localizationsDelegates: const [
      ...GlobalMaterialLocalizations.delegates,
      GlobalMuiLocalizations.delegate,
    ],
  ),
);

void main() {
  setUpAll(setupPluralResolvers);
  setUp(() {
    getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
    PackageInfo.setMockInitialValues(
      appName: 'Moodiary',
      packageName: 'moodiary',
      version: '3.0.0',
      buildNumber: '100',
      buildSignature: '',
    );
  });
  tearDown(getIt.reset);

  testWidgets(
    'Me retains the rolling 53-week level heatmap and day selection',
    (tester) async {
      final repository = _PendingMoods();
      repository.pending.complete([]);
      getIt.registerSingleton<MoodInsightsRepository>(repository);
      getIt.registerSingleton<DiaryRepository>(_Diaries());
      final router = _host(const MePage());
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardControllerProvider.overrideWith(_ReadyDashboard.new),
            placeControllerProvider.overrideWith(_Places.new),
          ],
          child: _app(router),
        ),
      );
      await tester.pumpAndSettle();
      final map = find.byType(MHeatmap);
      final heatmap = tester.widget<MHeatmap>(map);
      expect(heatmap.weeks, 53);
      expect(heatmap.endDate, _ReadyDashboard.today);
      expect(heatmap.levels, {_ReadyDashboard.today: 3});
      final legend = find.byType(MHeatmapLegend);
      final scale = tester.widget<MHeatmapLegend>(legend);
      expect(scale.lessLabel, l10n.app.meLegendLess);
      expect(scale.moreLabel, l10n.app.meLegendMore);
      expect(scale.colors, isNull);
      expect(
        tester
            .widgetList<Container>(
              find.descendant(of: legend, matching: find.byType(Container)),
            )
            .map((swatch) => (swatch.decoration! as BoxDecoration).color),
        [
          for (var i = 0; i < 5; i++)
            MHeatmap.levelColor(tester.element(legend), i),
        ],
      );
      final cells = find.descendant(of: map, matching: find.byType(Container));
      final decoration =
          tester.widget<Container>(cells.last).decoration! as BoxDecoration;
      expect(decoration.color, MHeatmap.levelColor(tester.element(map), 3));
      await tester.tap(cells.last);
      await tester.pumpAndSettle();
      expect(tester.widget<MHeatmap>(map).selected, _ReadyDashboard.today);
      await tester.tap(cells.last);
      await tester.pumpAndSettle();
      expect(tester.widget<MHeatmap>(map).selected, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final recorded in [true, false]) {
    testWidgets(
      recorded
          ? 'Me shows a skeleton while loading, then the populated mood card'
          : 'Me shows a skeleton while loading, then the empty mood card',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _PendingMoods()..recorded = recorded;
        getIt.registerSingleton<MoodInsightsRepository>(repository);
        getIt.registerSingleton<DiaryRepository>(_Diaries());
        final router = _host(const MePage());
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dashboardControllerProvider.overrideWith(_Dashboard.new),
              placeControllerProvider.overrideWith(_Places.new),
            ],
            child: _app(router),
          ),
        );
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        final card = find.byType(MoodInsightsCard);
        expect(card, findsOneWidget);
        expect(
          tester.widget<MSkeleton>(find.byType(MSkeleton)).enabled,
          isTrue,
        );
        expect(find.byWidgetPredicate((w) => w is Bone), findsNWidgets(7));
        final loadingHeight = tester.getSize(card).height;
        final today = moodDayKey(DateTime.now());
        repository.pending.complete([
          if (recorded)
            MoodInsightEntry(id: 'actual', time: today, mood: .great),
        ]);
        await tester.pumpAndSettle();
        expect(card, findsOneWidget);
        expect(find.byType(MSkeleton), findsNothing);
        expect(find.byWidgetPredicate((w) => w is Bone), findsNothing);
        expect(tester.getSize(card).height, loadingHeight);
        if (recorded) {
          expect(find.text('5.0'), findsOneWidget);
          expect(
            find.text(
              l10n.insights.monthMood(level: DiaryMood.great.labelOf(l10n)),
            ),
            findsOneWidget,
          );
          expect(find.text(l10n.insights.empty), findsNothing);
        } else {
          expect(find.text(l10n.insights.empty), findsOneWidget);
          expect(find.text('–'), findsNothing);
          expect(find.byType(MoodDeltaPill), findsNothing);
          expect(
            tester
                .widgetList<MoodGlyph>(find.byType(MoodGlyph))
                .map((g) => g.mood),
            everyElement(isNull),
          );
          expect(find.text(l10n.insights.title), findsOneWidget);
          await tester.tap(card);
          await tester.pumpAndSettle();
          expect(find.text('insights-destination'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Me omits the mood card when loading fails without data', (
    tester,
  ) async {
    final router = _host(const MePage());
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardControllerProvider.overrideWith(_Dashboard.new),
          moodInsightsControllerProvider.overrideWith(_FailedMoods.new),
          placeControllerProvider.overrideWith(_Places.new),
        ],
        child: _app(router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MoodInsightsCard), findsNothing);
    expect(find.byType(MSkeleton), findsNothing);
    expect(find.text(l10n.app.dashJournalDays), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Me card shows month average, delta, rolling glyphs and opens insights',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final today = DateTime(2026, 10, 21);
      final month = summarizeMood([
        MoodInsightEntry(id: 'a', time: today, mood: DiaryMood.good),
      ]);
      final data = MoodInsightsCardData(
        month: month,
        delta: .5,
        lastSevenDays: [null, null, null, null, null, null, month.days[today]],
        hasRecordedMood: true,
        today: today,
      );
      final router = _host(MoodInsightsCard(data: data));
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      expect(find.text('4.0'), findsOneWidget);
      expect(
        find.text(l10n.insights.monthMood(level: DiaryMood.good.labelOf(l10n))),
        findsOneWidget,
      );
      expect(find.byType(MoodGlyph), findsNWidgets(7));
      expect(find.text('+0.5'), findsOneWidget);
      await tester.tap(find.byType(MoodInsightsCard));
      await tester.pumpAndSettle();
      expect(find.text('insights-destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'upgrade notice consumes flag once, uses version, and explores after closing',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      MoodiaryKVs.pendingMoodNotice.set(true);
      final router = _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showPendingMoodNotice(context),
            child: const Text('open'),
          ),
        ),
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(MoodiaryKVs.pendingMoodNotice.get(), isFalse);
      expect(find.text(l10n.insights.noticeTitle), findsOneWidget);
      expect(
        find.text(l10n.insights.noticeSubtitle(version: '3.0.0')),
        findsOneWidget,
      );
      expect(find.byType(MoodGlyph), findsNWidgets(5));
      await tester.tap(find.text(l10n.insights.noticeDone));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.insights.noticeTitle), findsNothing);
      MoodiaryKVs.pendingMoodNotice.set(true);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.insights.noticeExplore));
      await tester.pumpAndSettle();
      expect(find.text('insights-destination'), findsOneWidget);
      expect(find.text(l10n.insights.noticeTitle), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
