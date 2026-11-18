import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_diary/src/application/diary_filter.dart';
import 'package:moodiary_diary/src/application/diary_selection.dart';
import 'package:moodiary_diary/src/presentation/widget/category_drawer.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:mui/mui.dart';

import '../support/pump.dart';

Category cat(String id, String name) =>
    Category(id: id, categoryName: name, lastModified: DateTime(2026));

final _emptyCatalog = tagCatalogProvider.overrideWithValue(
  const .data((byId: <String, Tag>{}, usage: <TagUsage>[])),
);

Widget wrap({
  required List<Category> categories,
  required Map<String, int> byCategory,
  required int total,
}) => muiTestApp(
  const CategoryDrawer(),
  overrides: [
    _emptyCatalog,
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
    expect(find.text('旅行'), findsOneWidget);
    expect(find.text('标签'), findsNothing);
    expect(find.text('日常'), findsOneWidget);
    expect(find.text('阅读'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
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
    await t.pumpWidget(
      muiTestApp(
        const SizedBox.expand(),
        overrides: [
          _emptyCatalog,
          orderedCategoriesProvider.overrideWithValue(.data(three)),
          categoryDiaryCountsProvider.overrideWith(
            (ref) async => (byCategory: const {'tr': 2}, total: 8),
          ),
        ],
        drawer: const CategoryDrawer(),
        scaffoldKey: key,
      ),
    );
    final container = ProviderScope.containerOf(
      t.element(find.byType(MaterialApp)),
      listen: false,
    );

    expect(container.read(homeDiaryFilterProvider).isAll, isTrue);
    container.read(diarySelectionProvider.notifier).enter('some-diary-id');
    expect(container.read(diarySelectionProvider), isNotEmpty);

    key.currentState!.openDrawer();
    await t.pumpAndSettle();
    await t.tap(find.text('旅行'));
    await t.pumpAndSettle();
    expect(
      container.read(homeDiaryFilterProvider),
      const DiaryFilter.category('tr'),
    );
    expect(container.read(diarySelectionProvider), isEmpty);
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

  testWidgets('tag search selects and retains a tag outside the top eight', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(600, 1100));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final key = GlobalKey<ScaffoldState>();
    final usage = [
      for (var i = 0; i <= 10; i++)
        (
          name: 'Tag $i',
          ids: {'id$i'},
          count: 10 - i,
          lastUsed: DateTime(2026),
        ),
    ];
    await t.pumpWidget(
      muiTestApp(
        const SizedBox.expand(),
        drawer: const CategoryDrawer(),
        scaffoldKey: key,
        overrides: [
          orderedCategoriesProvider.overrideWithValue(const .data([])),
          categoryDiaryCountsProvider.overrideWith(
            (_) async => (byCategory: <String, int>{}, total: 10),
          ),
          tagCatalogProvider.overrideWithValue(
            .data((byId: <String, Tag>{}, usage: usage)),
          ),
        ],
      ),
    );
    key.currentState!.openDrawer();
    await t.pumpAndSettle();
    expect(find.text('标签'), findsOneWidget);
    expect(find.text('10 个'), findsOneWidget);
    expect(find.byIcon(LucideIcons.hash), findsNWidgets(8));
    final top = find
        .ancestor(of: find.text('Tag 0'), matching: find.byType(Row))
        .first;
    expect(find.descendant(of: top, matching: find.text('10')), findsOneWidget);
    expect(find.text('Tag 8'), findsNothing);
    await t.enterText(find.byType(SearchBar), 'tAG');
    await t.pumpAndSettle();
    expect(find.byIcon(LucideIcons.hash), findsNWidgets(10));
    expect(find.text('Tag 10'), findsNothing);
    await t.tap(find.text('Tag 9'));
    await t.pumpAndSettle();
    final container = ProviderScope.containerOf(
      t.element(find.byType(MaterialApp)),
      listen: false,
    );
    expect(
      container.read(homeDiaryFilterProvider),
      const DiaryFilter.tag('Tag 9'),
    );
    key.currentState!.openDrawer();
    await t.pumpAndSettle();
    expect(find.text('Tag 8'), findsNothing);
    final label = find.text('Tag 9');
    final surface = t.widget<Material>(
      find.ancestor(of: label, matching: find.byType(Material)).first,
    );
    expect(surface.color, t.element(label).theme.colors.secondaryContainer);
  });

  testWidgets('a selected unused tag keeps the tag section visible', (t) async {
    final tag = Tag.create('Trip');
    await t.pumpWidget(
      muiTestApp(
        const CategoryDrawer(),
        overrides: [
          orderedCategoriesProvider.overrideWithValue(const .data([])),
          categoryDiaryCountsProvider.overrideWith(
            (_) async => (byCategory: <String, int>{}, total: 0),
          ),
          tagCatalogProvider.overrideWithValue(
            .data((
              byId: {tag.id: tag},
              usage: [
                (name: tag.name, ids: {tag.id}, count: 0, lastUsed: null),
              ],
            )),
          ),
        ],
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('标签'), findsNothing);
    final container = ProviderScope.containerOf(
      t.element(find.byType(MaterialApp)),
      listen: false,
    );
    container.read(homeDiaryFilterProvider.notifier).select(.tag(tag.name));
    await t.pumpAndSettle();
    expect(find.text('标签'), findsOneWidget);
    final row = find
        .ancestor(of: find.text(tag.name), matching: find.byType(Row))
        .first;
    expect(find.descendant(of: row, matching: find.text('0')), findsOneWidget);
  });

  testWidgets('counts stay blank until the query lands', (t) async {
    await t.pumpWidget(
      muiTestApp(
        const CategoryDrawer(),
        overrides: [
          _emptyCatalog,
          orderedCategoriesProvider.overrideWithValue(.data(three)),
          categoryDiaryCountsProvider.overrideWith(
            (ref) =>
                Completer<({Map<String, int> byCategory, int total})>().future,
          ),
        ],
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
