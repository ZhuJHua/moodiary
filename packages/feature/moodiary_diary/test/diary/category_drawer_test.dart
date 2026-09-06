import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_diary/src/application/diary_filter.dart';
import 'package:moodiary_diary/src/application/diary_selection.dart';
import 'package:moodiary_diary/src/presentation/widget/category_drawer.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:mui/mui.dart';

import '../support/pump.dart';

final _mui = buildMuiTheme(brightness: Brightness.light);

Category cat(String id, String name) =>
    Category(id: id, categoryName: name, lastModified: DateTime(2026));

Widget wrap({
  required List<Category> categories,
  required Map<String, int> byCategory,
  required int total,
  ProviderContainer? container,
}) => muiTestApp(
  const CategoryDrawer(),
  overrides: [
    orderedCategoriesProvider.overrideWithValue(.data(categories)),
    categoryDiaryCountsProvider.overrideWith(
      (ref) async => (byCategory: byCategory, total: total),
    ),
  ],
);

void main() {
  setUp(() => getIt.registerSingleton(SyncPendingTracker()));
  tearDown(getIt.reset);

  final three = [cat('tr', '旅行'), cat('dy', '日常'), cat('rd', '阅读')];

  testWidgets('lists every category with its count', (t) async {
    await t.pumpWidget(
      wrap(
        categories: three,
        byCategory: const {'tr': 2, 'dy': 4, 'rd': 1},
        total: 8,
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('旅行'), findsOneWidget);
    expect(find.text('日常'), findsOneWidget);
    expect(find.text('阅读'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('uncategorized count is total minus the categorised ones', (
    t,
  ) async {
    await t.pumpWidget(
      wrap(
        categories: three,
        byCategory: const {'tr': 2, 'dy': 4, 'rd': 1},
        total: 8,
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('未分类'), findsNothing);
    expect(find.text('无分类'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2));
  });

  testWidgets('never shows a negative uncategorized count', (t) async {
    await t.pumpWidget(
      wrap(categories: three, byCategory: const {'tr': 9}, total: 2),
    );
    await t.pumpAndSettle();
    expect(find.text('-7'), findsNothing);
  });

  testWidgets('picking a category writes the filter and closes the drawer', (
    t,
  ) async {
    final key = GlobalKey<ScaffoldState>();
    late ProviderContainer container;
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          orderedCategoriesProvider.overrideWithValue(.data(three)),
          categoryDiaryCountsProvider.overrideWith(
            (ref) async => (byCategory: const {'tr': 2}, total: 8),
          ),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return TranslationProvider(
              child: MuiTheme(
                data: _mui,
                child: MaterialApp(
                  localizationsDelegates: const [
                    ...GlobalMaterialLocalizations.delegates,
                    GlobalMuiLocalizations.delegate,
                  ],
                  supportedLocales: AppLocaleUtils.supportedLocales,
                  locale: const Locale('zh'),
                  home: Scaffold(
                    key: key,
                    drawer: const CategoryDrawer(),
                    body: const SizedBox.expand(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    expect(container.read(homeDiaryFilterProvider).isAll, isTrue);

    key.currentState!.openDrawer();
    await t.pumpAndSettle();
    await t.tap(find.text('旅行'));
    await t.pumpAndSettle();
    expect(
      container.read(homeDiaryFilterProvider),
      const DiaryFilter.category('tr'),
    );
    expect(find.text('管理分类'), findsNothing);

    key.currentState!.openDrawer();
    await t.pumpAndSettle();
    await t.tap(find.text('无分类'));
    await t.pumpAndSettle();
    expect(
      container.read(homeDiaryFilterProvider),
      const DiaryFilter.uncategorized(),
    );
  });

  testWidgets('picking a category drops the pending multi-selection', (
    t,
  ) async {
    final key = GlobalKey<ScaffoldState>();
    late ProviderContainer container;
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          orderedCategoriesProvider.overrideWithValue(.data(three)),
          categoryDiaryCountsProvider.overrideWith(
            (ref) async => (byCategory: const {'tr': 2}, total: 8),
          ),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return TranslationProvider(
              child: MuiTheme(
                data: _mui,
                child: MaterialApp(
                  localizationsDelegates: const [
                    ...GlobalMaterialLocalizations.delegates,
                    GlobalMuiLocalizations.delegate,
                  ],
                  supportedLocales: AppLocaleUtils.supportedLocales,
                  locale: const Locale('zh'),
                  home: Scaffold(
                    key: key,
                    drawer: const CategoryDrawer(),
                    body: const SizedBox.expand(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    container.read(diarySelectionProvider.notifier).enter('some-diary-id');
    expect(container.read(diarySelectionProvider), isNotEmpty);

    key.currentState!.openDrawer();
    await t.pumpAndSettle();
    await t.tap(find.text('旅行'));
    await t.pumpAndSettle();

    expect(container.read(diarySelectionProvider), isEmpty);
  });

  testWidgets('counts stay blank until the query lands', (t) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          orderedCategoriesProvider.overrideWithValue(.data(three)),
          categoryDiaryCountsProvider.overrideWith(
            (ref) =>
                Completer<({Map<String, int> byCategory, int total})>().future,
          ),
        ],
        child: TranslationProvider(
          child: MuiTheme(
            data: _mui,
            child: MaterialApp(
              localizationsDelegates: const [
                ...GlobalMaterialLocalizations.delegates,
                GlobalMuiLocalizations.delegate,
              ],
              supportedLocales: AppLocaleUtils.supportedLocales,
              locale: const Locale('zh'),
              home: const Scaffold(body: CategoryDrawer()),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    expect(find.text('旅行'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('the manage entry is always reachable', (t) async {
    await t.pumpWidget(wrap(categories: three, byCategory: const {}, total: 0));
    await t.pumpAndSettle();
    expect(find.text('管理分类'), findsOneWidget);
  });

  testWidgets('search box only appears once categories pile up', (t) async {
    await t.pumpWidget(wrap(categories: three, byCategory: const {}, total: 0));
    await t.pumpAndSettle();
    expect(find.byType(SearchBar), findsNothing);

    await t.pumpWidget(
      wrap(
        categories: [for (var i = 0; i < 9; i++) cat('c$i', '分类$i')],
        byCategory: const {},
        total: 0,
      ),
    );
    await t.pumpAndSettle();
    expect(find.byType(SearchBar), findsOneWidget);
  });
}
