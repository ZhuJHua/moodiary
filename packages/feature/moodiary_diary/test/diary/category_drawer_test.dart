import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary/src/presentation/controllers/diary_filter.dart';
import 'package:moodiary_diary/src/presentation/controllers/diary_selection.dart';
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
    expect(find.byTooltip('管理标签'), findsOneWidget);
    expect(find.text('标签'), findsOneWidget);
    expect(find.text('分类'), findsOneWidget);
    expect(find.text('日常'), findsOneWidget);
    expect(find.text('阅读'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('未分类'), findsNothing);
    expect(find.text('无分类'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2));
  });

  testWidgets('uncategorized stays hidden at zero except when selected', (
    t,
  ) async {
    await t.pumpWidget(
      wrap(categories: three, byCategory: const {'tr': 9}, total: 2),
    );
    await t.pumpAndSettle();
    expect(find.text('无分类'), findsNothing);
    final container = ProviderScope.containerOf(
      t.element(find.byType(MaterialApp)),
      listen: false,
    );
    container
        .read(homeDiaryFilterProvider.notifier)
        .select(const .uncategorized());
    await t.pumpAndSettle();
    expect(find.text('无分类'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('rows use a selection bar and no background fill', (t) async {
    await t.pumpWidget(
      wrap(categories: [three.first], byCategory: const {'tr': 2}, total: 3),
    );
    await t.pumpAndSettle();
    final container = ProviderScope.containerOf(
      t.element(find.byType(MaterialApp)),
      listen: false,
    );
    final colors = t.element(find.text('全部日记')).theme.colors;
    final rows = [
      ('全部日记', const DiaryFilter.all(), colors.onSurface),
      (
        '旅行',
        const DiaryFilter.category('tr'),
        categoryColorOf(colorValue: three.first.color, id: three.first.id),
      ),
      ('无分类', const DiaryFilter.uncategorized(), colors.onSurface),
    ];
    final bars = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.constraints ==
              const BoxConstraints.tightFor(width: 3, height: 20),
    );
    expect(t.widget<Icon>(find.byIcon(LucideIcons.bookOpen)).size, 18);
    final drawerMaterial = find
        .ancestor(of: find.byType(ListView), matching: find.byType(Material))
        .first;
    for (final (label, filter, color) in rows) {
      container.read(homeDiaryFilterProvider.notifier).select(filter);
      await t.pumpAndSettle();
      expect(bars, findsOneWidget);
      for (final (rowLabel, rowFilter, _) in rows) {
        final row = find.widgetWithText(MInkWell, rowLabel);
        expect(t.getSize(row).height, rowFilter.isAll ? 48 : 44);
        expect(t.widget<MInkWell>(row).borderRadius, MuiRadius.md);
        expect(
          t.element(
            find.ancestor(of: row, matching: find.byType(Material)).first,
          ),
          t.element(drawerMaterial),
        );
        final semantics = find
            .ancestor(of: row, matching: find.byType(Semantics))
            .first;
        expect(
          t.widget<Semantics>(semantics).properties.selected,
          rowLabel == label,
        );
      }
      final row = find.widgetWithText(MInkWell, label);
      final bar = find.descendant(of: row, matching: bars);
      expect(
        (t.widget<Container>(bar).decoration! as BoxDecoration).color,
        color,
      );
      expect(t.getTopLeft(bar).dx, t.getTopLeft(row).dx);
      expect(t.getCenter(bar).dy, t.getCenter(row).dy);
    }
  });

  testWidgets('empty hints appear after loading and honor pending categories', (
    t,
  ) async {
    final categories = Completer<List<Category>>();
    final categoryProvider = FutureProvider((_) => categories.future);
    final tags = Completer<({Map<String, Tag> byId, List<TagUsage> usage})>();
    await t.pumpWidget(
      muiTestApp(
        const CategoryDrawer(),
        overrides: [
          orderedCategoriesProvider.overrideWith(
            (ref) => ref.watch(categoryProvider),
          ),
          tagCatalogProvider.overrideWith((_) => tags.future),
          categoryDiaryCountsProvider.overrideWithValue(
            const .data((byCategory: <String, int>{}, total: 3)),
          ),
        ],
      ),
    );
    final noCategories = find.text('还没有分类，点右侧图标新建');
    final noTags = find.text('还没有标签，点右侧图标新建');
    expect(noCategories, findsNothing);
    expect(noTags, findsNothing);

    final tracker = ProviderScope.containerOf(
      t.element(find.byType(CategoryDrawer)),
      listen: false,
    ).read(syncPendingStateProvider.notifier);
    tracker.begin(
      newDiaryIds: {},
      updateDiaryIds: {},
      newCategoryIds: {'new'},
      updateCategoryIds: {},
    );
    categories.complete([]);
    tags.complete((byId: <String, Tag>{}, usage: <TagUsage>[]));
    await t.pump();
    await t.pump();
    expect(find.text('正在同步分类…'), findsOneWidget);
    expect(noCategories, findsNothing);
    expect(noTags, findsOneWidget);

    tracker.clear();
    await t.pumpAndSettle();
    expect(noCategories, findsOneWidget);
    expect(noTags, findsOneWidget);
    expect(find.text('全部日记'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('无分类'), findsNothing);
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
    expect(key.currentState!.isDrawerOpen, isFalse);

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
        (name: 'Tag $i', count: 10 - i, lastUsed: DateTime(2026)),
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
    expect(find.text('更多 2'), findsOneWidget);
    final tags = find.byWidgetPredicate(
      (widget) => widget is MChip && widget.variant == .tonal,
    );
    expect(tags, findsNWidgets(8));
    final top = find
        .ancestor(of: find.text('#Tag 0'), matching: find.byType(Row))
        .first;
    expect(find.descendant(of: top, matching: find.text('10')), findsOneWidget);
    expect(find.text('#Tag 8'), findsNothing);
    await t.enterText(find.byType(SearchBar), 'tAG');
    await t.pumpAndSettle();
    expect(tags, findsNWidgets(10));
    expect(
      find.byWidgetPredicate(
        (widget) => widget is MChip && widget.variant == .ghost,
      ),
      findsNothing,
    );
    expect(find.text('全部日记'), findsNothing);
    expect(find.text('无分类'), findsNothing);
    expect(find.text('#Tag 10'), findsNothing);
    await t.tap(find.text('#Tag 9'));
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
    expect(find.text('#Tag 8'), findsNothing);
    expect(find.text('更多 1'), findsOneWidget);
    final chip = find.widgetWithText(MChip, '#Tag 9');
    expect(t.widget<MChip>(chip).selected, isTrue);
    expect(t.getSize(chip).height, 32);
    await t.enterText(find.byType(SearchBar), 'tag 0');
    await t.pumpAndSettle();
    expect(find.text('#Tag 0'), findsOneWidget);
    expect(chip, findsNothing);
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
              usage: [(name: tag.name, count: 0, lastUsed: null)],
            )),
          ),
        ],
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('标签'), findsOneWidget);
    expect(find.byTooltip('管理标签'), findsOneWidget);
    expect(find.byType(MChip), findsNothing);
    expect(find.text('还没有标签，点右侧图标新建'), findsNothing);
    final container = ProviderScope.containerOf(
      t.element(find.byType(MaterialApp)),
      listen: false,
    );
    container.read(homeDiaryFilterProvider.notifier).select(.tag(tag.name));
    await t.pumpAndSettle();
    expect(find.text('标签'), findsOneWidget);
    final row = find
        .ancestor(of: find.text('#${tag.name}'), matching: find.byType(Row))
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
    final container = ProviderScope.containerOf(
      t.element(find.byType(MaterialApp)),
      listen: false,
    );
    container
        .read(homeDiaryFilterProvider.notifier)
        .select(const .category('c1'));
    container
        .read(syncPendingStateProvider.notifier)
        .begin(
          newDiaryIds: {},
          updateDiaryIds: {},
          newCategoryIds: {'new'},
          updateCategoryIds: {'c0'},
        );
    await t.enterText(find.byType(SearchBar), '分类0');
    await t.pump();
    expect(
      find.descendant(of: find.byType(ListView), matching: find.text('分类0')),
      findsOneWidget,
    );
    expect(find.byIcon(LucideIcons.cloudUpload), findsOneWidget);
    expect(find.text('分类1'), findsNothing);
    expect(find.text('正在同步分类…'), findsNothing);
    expect(find.text('全部日记'), findsNothing);
    expect(find.text('无分类'), findsNothing);
    await t.enterText(find.byType(SearchBar), '无分类');
    await t.pump();
    expect(
      find.descendant(of: find.byType(ListView), matching: find.text('无分类')),
      findsOneWidget,
    );
    expect(find.text('没有匹配的分类或标签'), findsNothing);
    await t.enterText(find.byType(SearchBar), 'missing');
    await t.pump();
    expect(find.text('没有匹配的分类或标签'), findsOneWidget);
    expect(find.text('无分类'), findsNothing);
  });
}
