import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary/moodiary_diary.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_card_parts.dart';
import 'package:moodiary_diary/src/presentation/widget/feed_tile.dart';
import 'package:moodiary_diary/src/presentation/widget/timeline_tile.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

import 'support/pump.dart';

class _PagedDiaries extends Fake implements DiaryRepository {
  final requests = <(DiarySort, int)>[];
  final limits = <int>[];
  final events = StreamController<DiaryEvent>.broadcast(sync: true);
  var secondPage = Completer<List<DiarySummary>>();
  Completer<List<DiarySummary>>? pendingLastModifiedFirstPage;
  Completer<List<DiarySummary>>? pendingFirstPage;
  final rows = [
    for (var day = 1; day <= 31; day++)
      Diary.empty(type: .markdown).copyWith(
        id: 'entry-$day',
        title: 'Entry $day',
        time: DateTime(2026, 1, day, 8),
        lastModified: DateTime(2026, day == 1 ? 3 : 2, 1, 17, day),
      ),
  ];

  @override
  Stream<DiaryEvent> get diaryEvents => events.stream;

  @override
  Future<List<DiarySummary>> getDiarySummariesByCategory({
    String? categoryId,
    bool uncategorized = false,
    String? tagName,
    int? offset,
    int? limit,
    DiarySort sort = .timeDesc,
  }) async {
    requests.add((sort, offset!));
    limits.add(limit!);
    if (offset > 0) return secondPage.future;
    if (pendingFirstPage case final pending?) {
      pendingFirstPage = null;
      return pending.future;
    }
    if (sort == .lastModifiedDesc && pendingLastModifiedFirstPage != null) {
      return pendingLastModifiedFirstPage!.future;
    }
    return (rows.toList()..sort(diarySortComparator(sort)))
        .take(limit)
        .map(diarySummaryFromDiary)
        .toList();
  }

  @override
  Future<Map<DateTime, int>> diaryCountByMonth({
    String? categoryId,
    bool uncategorized = false,
    String? tagName,
    DiarySort sort = .timeDesc,
  }) async => sort == .lastModifiedDesc
      ? {DateTime(2026, 3): 1, DateTime(2026, 2): 30}
      : {DateTime(2026, 1): 31};
}

void main() {
  for (final (name, view) in <(String, Widget)>[
    ('feed', const DiaryFeedView()),
    ('timeline', const DiaryTimelineView()),
  ]) {
    testWidgets('$name keeps unrelated tiles built during selection and sync', (
      tester,
    ) async {
      KVStore.installForTesting(MemoryKVStorage());
      addTearDown(KVStore.resetForTesting);
      final repository = _PagedDiaries()..rows.removeRange(0, 29);
      addTearDown(repository.events.close);
      await tester.pumpWidget(
        muiTestApp(
          view,
          overrides: [diaryRepositoryProvider.overrideWithValue(repository)],
        ),
      );
      await tester.pumpAndSettle();

      const firstId = 'entry-31';
      const secondId = 'entry-30';
      final first = find.byKey(const ValueKey(firstId));
      final second = find.byKey(const ValueKey(secondId));
      final container = ProviderScope.containerOf(
        tester.element(first),
        listen: false,
      );
      final selection = container.read(diarySelectionProvider.notifier);
      selection.enter(firstId);
      await tester.pumpAndSettle();
      final firstTile = tester.widget(first);

      Future<void> expectOnlySecondRebuilt(VoidCallback update) async {
        final previous = tester.widget(second);
        update();
        await tester.pump();
        expect(tester.widget(first), same(firstTile));
        expect(tester.widget(second), isNot(same(previous)));
      }

      await expectOnlySecondRebuilt(() => selection.toggle(secondId));
      await expectOnlySecondRebuilt(() {
        container.read(syncDirtyDiaryIdsProvider.notifier).markDirty(secondId);
      });
      await expectOnlySecondRebuilt(() {
        container
            .read(syncPendingStateProvider.notifier)
            .begin(
              newDiaryIds: {},
              updateDiaryIds: {secondId},
              newCategoryIds: {},
              updateCategoryIds: {},
            );
      });
      expect(find.byType(SyncPendingSummaryCard), findsOneWidget);
    });

    testWidgets('$name loads the next page as the list scrolls', (
      tester,
    ) async {
      KVStore.installForTesting(MemoryKVStorage());
      addTearDown(KVStore.resetForTesting);
      final repository = _PagedDiaries();
      addTearDown(repository.events.close);
      await tester.pumpWidget(
        muiTestApp(
          view,
          overrides: [diaryRepositoryProvider.overrideWithValue(repository)],
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable);
      expect(repository.requests, [(DiarySort.timeDesc, 0)]);

      for (var drag = 0; drag < 12 && repository.requests.length == 1; drag++) {
        await tester.drag(scrollable, const Offset(0, -320));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(repository.requests, [
        (DiarySort.timeDesc, 0),
        (DiarySort.timeDesc, 30),
      ]);
      repository.secondPage.complete([
        diarySummaryFromDiary(repository.rows.first),
      ]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('$name metadata fits at 320px and scale $scale', (
        tester,
      ) async {
        await tester.runAsync(() async {
          final font = FontLoader('Dosis')
            ..addFont(rootBundle.load('packages/mui/assets/fonts/Dosis.ttf'));
          await font.load();
        });
        final theme = buildMuiTheme(
          brightness: .light,
          font: const MuiFontConfig(family: 'Dosis'),
        );
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 640);
        addTearDown(tester.view.reset);
        KVStore.installForTesting(MemoryKVStorage());
        addTearDown(KVStore.resetForTesting);
        final repository = _PagedDiaries();
        addTearDown(repository.events.close);
        final time = DateTime(2000, 12, 31, 23, 59);
        final place = Place(
          id: 'place',
          name: '很长的地点名称' * 12,
          latitude: 1,
          longitude: 2,
          lastModified: time,
        );
        repository.rows
          ..clear()
          ..addAll([
            for (final (id, stamp) in [
              ('syncing', time),
              ('dirty', time.subtract(const Duration(minutes: 1))),
            ])
              Diary.empty(type: .markdown).copyWith(
                id: id,
                time: stamp,
                lastModified: stamp,
                placeId: place.id,
                weather: const DiaryWeather(
                  icon: '101',
                  temp: '-12',
                  text: '多云',
                ),
                audioName: List.generate(12, (index) => '$index.m4a'),
                fileName: List.generate(34, (index) => '$index.pdf'),
              ),
          ]);
        await tester.pumpWidget(
          muiTestApp(
            view,
            overrides: [
              diaryRepositoryProvider.overrideWithValue(repository),
              placeByIdProvider(place.id).overrideWithValue(place),
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: MuiTheme(data: theme, child: child!),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byWidget(view)),
          listen: false,
        );
        container
            .read(syncPendingStateProvider.notifier)
            .begin(
              newDiaryIds: {'syncing'},
              updateDiaryIds: {},
              newCategoryIds: {},
              updateCategoryIds: {},
            );
        container.read(syncDirtyDiaryIdsProvider.notifier).markDirty('dirty');
        container.read(diarySelectionProvider.notifier).enter('dirty');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final metadata = find.byType(DiaryCardMeta);
        Finder inMeta(Finder matching) =>
            find.descendant(of: metadata, matching: matching);
        final stamp = name == 'feed'
            ? TimeFormat.compactDateTime(time)
            : TimeFormat.clock(time);
        expect(inMeta(find.textContaining(stamp)), findsOneWidget);
        expect(inMeta(find.text('12')), findsNWidgets(2));
        expect(inMeta(find.text('34')), findsNWidgets(2));
        expect(inMeta(find.byIcon(qweatherIcon('101')!)), findsNWidgets(2));
        expect(inMeta(find.byType(CircularProgressIndicator)), findsOneWidget);
        expect(inMeta(find.byIcon(LucideIcons.cloudUpload)), findsOneWidget);
        expect(inMeta(find.textContaining('-12°')), findsNWidgets(2));
        expect(inMeta(find.textContaining(place.name)), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'pinned month header follows the theme while its parent rebuilds',
    (tester) async {
      KVStore.installForTesting(MemoryKVStorage());
      addTearDown(KVStore.resetForTesting);
      final repository = _PagedDiaries();
      addTearDown(repository.events.close);
      final theme = ValueNotifier(Brightness.light);
      final timelineKey = GlobalKey();
      addTearDown(theme.dispose);
      final light = buildMuiTheme(brightness: .light);
      final dark = buildMuiTheme(brightness: .dark);
      await tester.pumpWidget(
        muiTestApp(
          ValueListenableBuilder(
            valueListenable: theme,
            builder: (_, brightness, _) => MuiTheme(
              data: brightness == Brightness.light ? light : dark,
              child: DiaryTimelineView(key: timelineKey),
            ),
          ),
          overrides: [diaryRepositoryProvider.overrideWithValue(repository)],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final month = find.text(TimeFormat.monthTitle(repository.rows.last.time));
      final header = find
          .ancestor(of: month, matching: find.byType(Stack))
          .first;
      Color background() => tester
          .widget<ColoredBox>(
            find
                .descendant(of: header, matching: find.byType(ColoredBox))
                .first,
          )
          .color;
      final scrollable = find.byType(Scrollable);
      tester.state<ScrollableState>(scrollable).position.jumpTo(180);
      await tester.pumpAndSettle();
      expect(tester.getSize(header).height, greaterThan(34));
      expect(tester.getTopLeft(header).dy, tester.getTopLeft(scrollable).dy);
      expect(background(), light.colorScheme.surface);
      theme.value = Brightness.dark;
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(header).dy, tester.getTopLeft(scrollable).dy);
      expect(background(), dark.colorScheme.surface);
    },
  );

  testWidgets('switching sort discards the in-flight second page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    KVStore.installForTesting(MemoryKVStorage());
    addTearDown(KVStore.resetForTesting);
    final repository = _PagedDiaries();
    addTearDown(repository.events.close);
    final timeline = ValueNotifier(false);
    addTearDown(timeline.dispose);
    await tester.pumpWidget(
      muiTestApp(
        ValueListenableBuilder<bool>(
          valueListenable: timeline,
          builder: (_, showTimeline, _) =>
              showTimeline ? const DiaryTimelineView() : const DiaryFeedView(),
        ),
        overrides: [diaryRepositoryProvider.overrideWithValue(repository)],
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiaryFeedView)),
      listen: false,
    );
    final provider = diaryControllerProvider();
    expect(container.read(provider).requireValue.items.first.id, 'entry-31');
    final scroll = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    scroll.jumpTo(240);
    await tester.pump();
    final pending = container.read(provider.notifier).loadMore();
    expect(repository.requests, [
      (DiarySort.timeDesc, 0),
      (DiarySort.timeDesc, 30),
    ]);
    final first = repository.pendingLastModifiedFirstPage =
        Completer<List<DiarySummary>>();
    MoodiaryKVs.homeSortMode.set(DiarySort.lastModifiedDesc.number);
    await tester.pump();
    await tester.pump();
    final oldPage = container.read(provider);
    expect(oldPage.isReloading, isTrue);
    expect(oldPage.requireValue.sort, DiarySort.timeDesc);
    expect(oldPage.requireValue.items.first.id, 'entry-31');
    final tiles = tester.widgetList<DiaryFeedTile>(find.byType(DiaryFeedTile));
    expect(tiles, isNotEmpty);
    expect(tiles.map((tile) => tile.sort), everyElement(DiarySort.timeDesc));
    expect(find.byType(MLoading), findsNothing);
    expect(scroll.pixels, 240);
    final expected =
        (repository.rows.toList()..sort(diarySortComparator(.lastModifiedDesc)))
            .take(30)
            .map(diarySummaryFromDiary)
            .toList();
    first.complete(expected);
    await tester.pumpAndSettle();
    expect(container.read(provider).requireValue.items, expected);
    expect(
      container.read(provider).requireValue.sort,
      DiarySort.lastModifiedDesc,
    );
    expect(scroll.pixels, 0);
    repository.secondPage.complete([
      diarySummaryFromDiary(repository.rows.first),
    ]);
    await pending;
    await tester.pumpAndSettle();
    expect(container.read(provider).requireValue.items, expected);
    final stamp = repository.rows.first.lastModified;
    expect(
      find.textContaining(
        TimeFormat.compactDateTime(stamp),
        findRichText: true,
      ),
      findsOneWidget,
    );
    timeline.value = true;
    await tester.pumpAndSettle();
    expect(find.text(TimeFormat.monthTitle(stamp)), findsOneWidget);
    final tile = tester.widget<DiaryTimelineTile>(
      find.byKey(ValueKey(repository.rows.first.id)),
    );
    expect(tile.stamp, stamp);
    expect(repository.requests, [
      (DiarySort.timeDesc, 0),
      (DiarySort.timeDesc, 30),
      (DiarySort.lastModifiedDesc, 0),
    ]);
    expect(tester.takeException(), isNull);
  });

  test('old second page completing before sort rebuild flush does not publish stale rows', () async {
    KVStore.installForTesting(MemoryKVStorage());
    addTearDown(KVStore.resetForTesting);
    final newFirstPage = Completer<List<DiarySummary>>();
    final repository = _PagedDiaries()
      ..pendingLastModifiedFirstPage = newFirstPage;
    addTearDown(repository.events.close);
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [diaryRepositoryProvider.overrideWithValue(repository)],
    );
    final provider = diaryControllerProvider();
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);

    final initial = await container.read(provider.future);
    expect(initial.items.first.id, 'entry-31');

    final pendingLoadMore = container.read(provider.notifier).loadMore();
    MoodiaryKVs.homeSortMode.set(DiarySort.lastModifiedDesc.number);
    // Complete old page 2 BEFORE container.pump() flushes the sort rebuild,
    // while the new sort's first-page query stays pending.
    repository.secondPage.complete([
      diarySummaryFromDiary(repository.rows.first),
    ]);
    await pendingLoadMore;

    // The notifier must stay loading the new sort and never have published
    // the stale page-2 data or marked noMore=true on the new epoch.
    expect(container.read(provider).isLoading, isTrue);
    expect(container.read(provider.notifier).noMore, isFalse);

    final expected =
        (repository.rows.toList()..sort(diarySortComparator(.lastModifiedDesc)))
            .take(30)
            .map(diarySummaryFromDiary)
            .toList();
    newFirstPage.complete(expected);
    await container.pump();
    expect((await container.read(provider.future)).items, expected);
  });

  for (final timeline in [false, true]) {
    testWidgets(
      '${timeline ? 'timeline' : 'feed'} retains its scroll position during append and sync summary changes',
      (tester) async {
        KVStore.installForTesting(MemoryKVStorage());
        addTearDown(KVStore.resetForTesting);
        final repository = _PagedDiaries();
        addTearDown(repository.events.close);
        await tester.pumpWidget(
          muiTestApp(
            timeline ? const DiaryTimelineView() : const DiaryFeedView(),
            overrides: [
              diaryRepositoryProvider.overrideWithValue(repository),
              tagCatalogProvider.overrideWithValue(
                const AsyncData((byId: {}, usage: [])),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        final scrollable = find.byType(Scrollable);
        final position = tester.state<ScrollableState>(scrollable).position;
        final container = ProviderScope.containerOf(
          tester.element(scrollable),
          listen: false,
        );
        position.jumpTo(320);
        await tester.pump();
        final provider = diaryControllerProvider();
        final pending = container.read(provider.notifier).loadMore();
        await tester.pump();
        expect(container.read(provider).requireValue.isLoadingMore, isTrue);
        expect(find.byType(MLoading), findsNothing);
        final summary = container.read(syncPendingStateProvider.notifier);
        summary.begin(
          newDiaryIds: {'entry-5'},
          updateDiaryIds: {},
          newCategoryIds: {},
          updateCategoryIds: {},
        );
        await tester.pump();
        expect(
          tester.state<ScrollableState>(scrollable).position,
          same(position),
        );
        expect(position.pixels, 320);
        summary.clear();
        repository.secondPage.complete([
          diarySummaryFromDiary(repository.rows.first),
        ]);
        await pending;
        await tester.pumpAndSettle();
        expect(
          tester.state<ScrollableState>(scrollable).position,
          same(position),
        );
        expect(position.pixels, 320);
      },
    );
  }

  testWidgets('a failed preload waits for an explicit footer retry', (
    tester,
  ) async {
    KVStore.installForTesting(MemoryKVStorage());
    addTearDown(KVStore.resetForTesting);
    final repository = _PagedDiaries();
    addTearDown(repository.events.close);
    await tester.pumpWidget(
      muiTestApp(
        const DiaryFeedView(),
        overrides: [
          diaryRepositoryProvider.overrideWithValue(repository),
          tagCatalogProvider.overrideWithValue(
            const AsyncData((byId: {}, usage: [])),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pump(const Duration(milliseconds: 16));
    expect(repository.requests.map((request) => request.$2), [0, 30]);
    repository.secondPage.completeError(StateError('SQL failed'));
    await tester.pumpAndSettle();
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(repository.requests.map((request) => request.$2), [0, 30]);
    repository.secondPage = Completer<List<DiarySummary>>();
    await tester.tap(find.text(l10n.common.retry));
    await tester.pump();
    expect(repository.requests.map((request) => request.$2), [0, 30, 30]);
    repository.secondPage.complete([
      diarySummaryFromDiary(repository.rows.first),
    ]);
    await tester.pumpAndSettle();
    expect(find.text(l10n.common.retry), findsNothing);
    expect(find.byType(DiaryFeedTile), findsWidgets);
  });

  group('page queries', () {
    late _PagedDiaries repository;
    late ProviderContainer container;
    final provider = diaryControllerProvider();
    setUp(() {
      KVStore.installForTesting(MemoryKVStorage());
      addTearDown(KVStore.resetForTesting);
      repository = _PagedDiaries();
      addTearDown(repository.events.close);
      container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [diaryRepositoryProvider.overrideWithValue(repository)],
      );
      container.listen(provider, (_, _) {});
    });

    test('events outside the loaded prefix preserve its identity', () async {
      final first = await container.read(provider.future);
      final outside = repository.rows.first;
      repository.events.add(DiaryEvent.updated(outside));
      expect(container.read(provider).requireValue.items, same(first.items));

      final changed = outside.copyWith(time: DateTime(2027), title: 'Moved');
      repository.events.add(DiaryEvent.updated(changed));
      expect(
        container.read(provider).requireValue.items.first,
        diarySummaryFromDiary(changed),
      );
    });

    test('append errors retain the rows and allow one retry', () async {
      final first = await container.read(provider.future);
      final notifier = container.read(provider.notifier);
      final pending = notifier.loadMore();
      expect(container.read(provider).requireValue.items, same(first.items));
      await notifier.loadMore();
      final error = StateError('SQL failed');
      repository.secondPage.completeError(error);
      await pending;
      final failed = container.read(provider).requireValue;
      expect(failed.items, same(first.items));
      expect(failed.isLoadingMore, isFalse);
      expect(failed.loadMoreError, same(error));
      repository.secondPage = Completer<List<DiarySummary>>();
      final retry = notifier.loadMore();
      expect(container.read(provider).requireValue.items, same(first.items));
      expect(container.read(provider).requireValue.loadMoreError, isNull);
      repository.secondPage.complete([
        diarySummaryFromDiary(repository.rows.first),
      ]);
      await retry;
      expect(container.read(provider).requireValue.items, [
        ...first.items,
        diarySummaryFromDiary(repository.rows.first),
      ]);
      expect(container.read(provider).requireValue.hasMore, isFalse);
      expect(repository.requests.map((query) => query.$2), [0, 30, 30]);
    });

    test(
      'failed first-page refresh keeps rows and surfaces the error',
      () async {
        final first = await container.read(provider.future);
        final notifier = container.read(provider.notifier);
        final append = notifier.loadMore();
        final pending = repository.pendingFirstPage =
            Completer<List<DiarySummary>>();
        final refresh = notifier.refresh();
        expect(await notifier.loadMore(), isFalse);
        final error = StateError('First-page query failed');
        final failed = expectLater(refresh, throwsA(same(error)));
        pending.completeError(error);
        await failed;
        expect(container.read(provider), isA<AsyncData>());
        final page = container.read(provider).requireValue;
        expect(page.items, first.items);
        expect(page.hasMore, first.hasMore);
        expect(page.isLoadingMore, isFalse);
        repository.secondPage.complete([
          diarySummaryFromDiary(repository.rows.first),
        ]);
        expect(await append, isFalse);
        expect(container.read(provider).requireValue, same(page));
        await notifier.refresh();
        expect(container.read(provider).requireValue.items, first.items);
      },
    );

    for (final insert in [false, true]) {
      test(
        '${insert ? 'insert' : 'delete'} during append reloads the accumulated window',
        () async {
          final first = await container.read(provider.future);
          final notifier = container.read(provider.notifier);
          final firstDiary = repository.rows.firstWhere(
            (diary) => diary.id == first.items.first.id,
          );
          repository.rows.addAll([
            for (var day = 1; day <= 70; day++)
              firstDiary.copyWith(
                id: 'older-$day',
                time: DateTime(2025, 1, day),
              ),
          ]);
          final ordered = repository.rows.toList()
            ..sort(diarySortComparator(.timeDesc));
          repository.secondPage.complete(
            ordered.sublist(30, 60).map(diarySummaryFromDiary).toList(),
          );
          await notifier.loadMore();
          expect(
            container.read(provider).requireValue.items,
            ordered.take(60).map(diarySummaryFromDiary),
          );
          repository.secondPage = Completer<List<DiarySummary>>();
          final pending = notifier.loadMore();
          if (insert) {
            final newDiary = firstDiary.copyWith(
              id: 'new',
              time: DateTime(2027),
            );
            repository.rows.add(newDiary);
            repository.events.add(DiaryEvent.created(newDiary));
          } else {
            repository.rows.remove(firstDiary);
            repository.events.add(DiaryEvent.deleted(first.items.first.id));
          }
          final length = container.read(provider).requireValue.items.length;
          repository.secondPage.complete(
            ordered.sublist(60, 90).map(diarySummaryFromDiary).toList(),
          );
          await pending;
          expect(repository.requests.map((query) => query.$2), [0, 30, 60, 0]);
          expect(repository.limits.last, length + 30);
          expect(
            container.read(provider).requireValue.items,
            (repository.rows.toList()..sort(diarySortComparator(.timeDesc)))
                .take(length + 30)
                .map(diarySummaryFromDiary),
          );
          expect(container.read(provider).requireValue.hasMore, isTrue);
        },
      );
    }

    test(
      'refresh reconciles an event received while page one is pending',
      () async {
        final old = await container.read(provider.future);
        final first = repository.pendingFirstPage =
            Completer<List<DiarySummary>>();
        final refreshed = container.read(provider.notifier).refresh();
        repository.rows.removeWhere((diary) => diary.id == old.items.first.id);
        repository.events.add(DiaryEvent.deleted(old.items.first.id));
        first.complete(old.items);
        await refreshed;
        expect(repository.requests.map((query) => query.$2), [0, 0, 0]);
        expect(
          container.read(provider).requireValue.items,
          (repository.rows.toList()..sort(diarySortComparator(.timeDesc))).map(
            diarySummaryFromDiary,
          ),
        );
      },
    );
  });
}
