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

class _Dashboard extends DashboardController {
  @override
  Future<DashboardStats> build() => Completer<DashboardStats>().future;
}

class _Places extends PlaceController {
  @override
  Future<List<Place>> build() async => [];
}

GoRouter host(Widget child) => GoRouter(
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

Widget app(GoRouter router) => TranslationProvider(
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

  for (final hint in [true, false]) {
    for (final recorded in [true, false]) {
      testWidgets(
        'Me hint=$hint shows skeleton or stays hidden, then persists recorded=$recorded',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repository = _PendingMoods()..recorded = recorded;
          getIt.registerSingleton<MoodInsightsRepository>(repository);
          getIt.registerSingleton<DiaryRepository>(_Diaries());
          MoodiaryKVs.moodCardHint.set(hint);
          final router = host(const MePage());
          addTearDown(router.dispose);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                dashboardControllerProvider.overrideWith(_Dashboard.new),
                placeControllerProvider.overrideWith(_Places.new),
              ],
              child: app(router),
            ),
          );
          await tester.pump();
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(
            find.byType(MoodInsightsCard),
            hint ? findsOneWidget : findsNothing,
          );
          Size? loadingSize;
          if (hint) {
            expect(
              tester.widget<MSkeleton>(find.byType(MSkeleton)).enabled,
              isTrue,
            );
            expect(find.byWidgetPredicate((w) => w is Bone), findsNWidgets(7));
            expect(
              find.textContaining(
                RegExp(r'^(记录|Recorded) \d+ / \d+ (天|days)$'),
              ),
              findsNothing,
            );
            expect(
              tester.getTopLeft(find.byType(MoodGlyph).first).dy -
                  tester.getBottomLeft(find.text('4.0')).dy,
              14,
            );
            loadingSize = tester.getSize(find.byType(MoodInsightsCard));
          }
          final today = moodDayKey(DateTime.now());
          repository.pending.complete([
            if (recorded)
              MoodInsightEntry(id: 'actual', time: today, mood: .great),
          ]);
          await tester.pumpAndSettle();
          expect(MoodiaryKVs.moodCardHint.get(), recorded);
          expect(
            find.byType(MoodInsightsCard),
            recorded ? findsOneWidget : findsNothing,
          );
          expect(find.byWidgetPredicate((w) => w is Bone), findsNothing);
          if (recorded) {
            expect(
              tester.widget<MSkeleton>(find.byType(MSkeleton)).enabled,
              isFalse,
            );
            expect(find.text('5.0'), findsOneWidget);
            if (loadingSize != null) {
              expect(
                tester.getSize(find.byType(MoodInsightsCard)),
                loadingSize,
              );
            }
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

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
      final router = host(MoodInsightsCard(data: data));
      addTearDown(router.dispose);
      await tester.pumpWidget(app(router));
      await tester.pumpAndSettle();
      expect(find.text('4.0'), findsOneWidget);
      expect(
        find.text(
          l10n.insights.monthAverage(level: DiaryMood.good.labelOf(l10n)),
        ),
        findsOneWidget,
      );
      expect(find.byType(MoodGlyph), findsNWidgets(7));
      expect(find.text('+0.5'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(MoodGlyph).first).dy -
            tester.getBottomLeft(find.text('4.0')).dy,
        14,
      );
      expect(
        find.textContaining(RegExp(r'^(记录|Recorded) \d+ / \d+ (天|days)$')),
        findsNothing,
      );
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
      final router = host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showPendingMoodNotice(context),
            child: const Text('open'),
          ),
        ),
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(app(router));
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
