import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary/moodiary_diary.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_card_parts.dart';
import 'package:moodiary_diary/src/presentation/widget/timeline_tile.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

import 'support/pump.dart';

class _PagedDiaries extends Fake implements DiaryRepository {
  final requests = <(DiarySort, int)>[];
  final secondPage = Completer<List<Diary>>();
  Completer<List<Diary>>? pendingLastModifiedFirstPage;
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
  Stream<DiaryEvent> get diaryEvents => const Stream.empty();

  @override
  Future<List<Diary>> getDiaryByCategory({
    String? categoryId,
    bool uncategorized = false,
    String? tagName,
    int? offset,
    int? limit,
    DiarySort sort = .timeDesc,
  }) async {
    requests.add((sort, offset!));
    if (offset > 0) return secondPage.future;
    if (sort == .lastModifiedDesc && pendingLastModifiedFirstPage != null) {
      return pendingLastModifiedFirstPage!.future;
    }
    return (rows.toList()..sort(diarySortComparator(sort)))
        .take(limit!)
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
    testWidgets('$name loads the next page as the list scrolls', (
      tester,
    ) async {
      KVStore.installForTesting(MemoryKVStorage());
      addTearDown(KVStore.resetForTesting);
      final repository = _PagedDiaries();
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
      repository.secondPage.complete([repository.rows.first]);
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
    expect(container.read(provider).requireValue.first.id, 'entry-31');
    final pending = container.read(provider.notifier).loadMore();
    expect(repository.requests, [
      (DiarySort.timeDesc, 0),
      (DiarySort.timeDesc, 30),
    ]);
    MoodiaryKVs.homeSortMode.set(DiarySort.lastModifiedDesc.number);
    await tester.pumpAndSettle();
    final expected =
        (repository.rows.toList()..sort(diarySortComparator(.lastModifiedDesc)))
            .take(30)
            .toList();
    expect(container.read(provider).requireValue, expected);
    repository.secondPage.complete([repository.rows.first]);
    await pending;
    await tester.pumpAndSettle();
    expect(container.read(provider).requireValue, expected);
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
    final newFirstPage = Completer<List<Diary>>();
    final repository = _PagedDiaries()
      ..pendingLastModifiedFirstPage = newFirstPage;
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [diaryRepositoryProvider.overrideWithValue(repository)],
    );
    final provider = diaryControllerProvider();
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);

    final initial = await container.read(provider.future);
    expect(initial.first.id, 'entry-31');

    final pendingLoadMore = container.read(provider.notifier).loadMore();
    MoodiaryKVs.homeSortMode.set(DiarySort.lastModifiedDesc.number);
    // Complete old page 2 BEFORE container.pump() flushes the sort rebuild,
    // while the new sort's first-page query stays pending.
    repository.secondPage.complete([repository.rows.first]);
    await pendingLoadMore;

    // The notifier must stay loading the new sort and never have published
    // the stale page-2 data or marked noMore=true on the new epoch.
    expect(container.read(provider).isLoading, isTrue);
    expect(container.read(provider.notifier).noMore, isFalse);

    final expected =
        (repository.rows.toList()..sort(diarySortComparator(.lastModifiedDesc)))
            .take(30)
            .toList();
    newFirstPage.complete(expected);
    await container.pump();
    expect(await container.read(provider.future), expected);
  });
}
