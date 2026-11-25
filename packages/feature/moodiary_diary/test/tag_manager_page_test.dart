import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary/moodiary_diary.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:mui/mui.dart';

import 'support/pump.dart';

void main() {
  late MoodiaryDatabase db;
  late TagRepository tags;
  late DiaryRepository diaries;
  late SmartConfigCustom previousCustom;

  setUpAll(setupPluralResolvers);

  setUp(() async {
    previousCustom = SmartDialog.config.custom;
    SmartDialog.config.custom = SmartConfigCustom(debounceTime: Duration.zero);
    db = MoodiaryDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement('PRAGMA foreign_keys = ON');
    tags = TagRepository(db);
    diaries = DiaryRepository(db);
  });

  tearDown(() {
    SmartDialog.config.custom = previousCustom;
  });

  Future<ProviderContainer> open(
    WidgetTester tester, {
    bool drawer = false,
    bool manageOnly = false,
  }) async {
    final key = GlobalKey<ScaffoldState>();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            key: key,
            drawer: const CategoryDrawer(),
            body: FilledButton(
              onPressed: () =>
                  TagManagerRoute(manageOnly: manageOnly).push(context),
              child: const Text('home'),
            ),
          ),
        ),
        ...diaryRoutes(),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      muiTestApp(
        Router.withConfig(config: router),
        overrides: [
          tagRepositoryProvider.overrideWithValue(tags),
          diaryRepositoryProvider.overrideWithValue(diaries),
          orderedCategoriesProvider.overrideWithValue(const .data([])),
          categoryDiaryCountsProvider.overrideWithValue(
            const .data((byCategory: <String, int>{}, total: 0)),
          ),
        ],
        builder: FlutterSmartDialog.init(),
      ),
    );
    await tester.pumpAndSettle();
    if (drawer) {
      key.currentState!.openDrawer();
      await tester.pumpAndSettle();
    }
    await tester.tap(drawer ? find.byTooltip('管理标签') : find.text('home'));
    await tester.pumpAndSettle();
    expect(find.text('标签管理'), findsOneWidget);
    expect(key.currentState!.isDrawerOpen, isFalse);
    return ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
  }

  Future<void> menu(WidgetTester tester, String name, String action) async {
    final tile = find.widgetWithText(ListTile, name);
    await tester.tap(
      find.descendant(
        of: tile,
        matching: find.byIcon(LucideIcons.ellipsisVertical),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester, String input) async {
    await tester.enterText(find.byType(TextField).last, input);
    await tester.tap(find.text('确认'));
    await pumpTransition(tester);
  }

  Future<void> settleChanges(WidgetTester tester) async {
    await pumpTransition(tester);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  Future<void> diary(String id, List<String> tagIds, int day) =>
      diaries.insertADiary(
        Diary.empty(type: .tiptap).copyWith(
          id: id,
          tagIds: tagIds,
          time: DateTime(2026, 9, day).toUtc(),
        ),
        index: .skip,
      );

  testWidgets('catalog order, subtitles, search, and selecting a tag', (
    tester,
  ) async {
    final ids = await tags.ensureTags([
      'Older',
      'Frequent',
      'Unused',
      'Beta',
      'Alpha',
    ]);
    await diary('one', [ids[0], ids[1]], 1);
    await diary('two', [ids[1], ids[3], ids[4]], 2);
    final container = await open(tester);
    expect(
      tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((tile) => (tile.title! as Text).data),
      ['Frequent', 'Alpha', 'Beta', 'Older', 'Unused'],
    );
    expect(find.text('2 篇 · 最近 9月2日'), findsOneWidget);
    expect(find.text('暂无日记'), findsOneWidget);
    final search = find.byType(TextField);
    await tester.enterText(search, 'absent');
    await tester.pump();
    expect(find.text('没有匹配的标签'), findsOneWidget);
    await tester.enterText(search, ' fRE ');
    await tester.pump();
    expect(find.byType(ListTile), findsOneWidget);
    container.read(diarySelectionProvider.notifier).enter('one');
    await tester.tap(find.text('Frequent'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(
      container.read(homeDiaryFilterProvider),
      const DiaryFilter.tag('Frequent'),
    );
    expect(container.read(diarySelectionProvider), isEmpty);
  });

  testWidgets('manage-only mode does not touch the home filter', (
    tester,
  ) async {
    await tags.ensureTags(['Work']);
    final container = await open(tester, manageOnly: true);
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    expect(find.text('标签管理'), findsOneWidget);
    expect(container.read(homeDiaryFilterProvider), const DiaryFilter.all());
  });

  testWidgets(
    'drawer opens manager for an unused tag, rename follows selection',
    (tester) async {
      await tags.ensureTags(['Old']);
      final container = await open(tester, drawer: true);
      container
          .read(homeDiaryFilterProvider.notifier)
          .select(const .tag('Old'));
      await menu(tester, 'Old', '重命名');
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        'Old',
      );
      await submit(tester, ' # New  name ');
      await settleChanges(tester);
      expect(find.text('New name'), findsOneWidget);
      expect((await tags.getTagUsage()).single.name, 'New name');
      expect(container.read(homeDiaryFilterProvider).tagName, 'New name');
    },
  );

  testWidgets('merge requires confirmation and preserves diary timestamps', (
    tester,
  ) async {
    final ids = await tags.ensureTags(['Source', 'Target']);
    await diary('entry', ids, 1);
    final before = (await diaries.getDiaryByBusinessId('entry'))!;
    await open(tester);
    await menu(tester, 'Source', '重命名');
    await submit(tester, 'Target');
    expect(
      find.text('#Target 已存在。确认后「Source」的 1 篇日记会合并到 #Target。'),
      findsOneWidget,
    );
    expect(await tags.getTagUsage(), hasLength(2));
    await tester.tap(find.text('合并'));
    await settleChanges(tester);
    final after = (await diaries.getDiaryByBusinessId('entry'))!;
    expect(after.lastModified, before.lastModified);
    expect(after.tagIds, before.tagIds);
    expect(
      resolveTagNames(
        after.tagIds,
        await tags.getTagsByIds(ids),
      ).map((tag) => tag.name),
      ['Target'],
    );
    expect((await tags.getTagUsage()).single.count, 1);
  });

  testWidgets('delete confirmation soft-deletes the tag', (tester) async {
    final ids = await tags.ensureTags(['Work']);
    await diary('entry', ids, 1);
    await open(tester);
    await menu(tester, 'Work', '删除');
    expect(find.text('1 篇日记将不再显示 #Work，回收站里的日记也一样。'), findsOneWidget);
    expect((await tags.getTagById(ids.single))!.deleted, isFalse);
    await tester.tap(find.text('删除'));
    await settleChanges(tester);
    expect((await tags.getTagById(ids.single))!.deleted, isTrue);
    expect(find.text('还没有标签'), findsOneWidget);
  });

  testWidgets('empty action creates a tag and FAB reports duplicates', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('新建标签'));
    await tester.pumpAndSettle();
    await submit(tester, '# New');
    await settleChanges(tester);
    expect(find.text('New'), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await submit(tester, 'New');
    expect(find.text('标签已存在'), findsOneWidget);
    expect(await tags.getAllTags(), hasLength(1));
    await settleChanges(tester);
  });
}
