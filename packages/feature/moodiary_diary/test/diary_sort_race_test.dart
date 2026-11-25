import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary/moodiary_diary.dart';
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
  testWidgets('switching sort discards the in-flight second page', (
    tester,
  ) async {
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
        overrides: [
          diaryRepositoryProvider.overrideWithValue(repository),
          tagCatalogProvider.overrideWithValue(
            const AsyncData((byId: {}, usage: [])),
          ),
        ],
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

  test(
    'old second page completing before sort rebuild flush does not publish stale rows',
    () async {
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
          (repository.rows.toList()
                ..sort(diarySortComparator(.lastModifiedDesc)))
              .take(30)
              .toList();
      newFirstPage.complete(expected);
      await container.pump();
      expect(await container.read(provider.future), expected);
    },
  );
}
