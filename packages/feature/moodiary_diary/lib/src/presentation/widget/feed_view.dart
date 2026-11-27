library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary/src/presentation/controllers/diary_controller.dart';
import 'package:moodiary_diary/src/presentation/controllers/diary_filter.dart';
import 'package:moodiary_diary/src/presentation/controllers/diary_selection.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_nav.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_page_scroll.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_tile_frame.dart';
import 'package:moodiary_diary/src/presentation/widget/feed_tile.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';

class DiaryFeedView extends ConsumerStatefulWidget {
  final DiaryFilter filter;
  final MRefreshCallback? onRefresh;
  final bool refreshEnabled;
  final MRefreshLabels? refreshLabels;

  const DiaryFeedView({
    super.key,
    this.filter = const .all(),
    this.onRefresh,
    this.refreshEnabled = true,
    this.refreshLabels,
  });

  @override
  ConsumerState<DiaryFeedView> createState() => _DiaryFeedViewState();
}

class _DiaryFeedViewState extends ConsumerState<DiaryFeedView>
    with DiaryPageScroll<DiaryFeedView> {
  @override
  Widget build(BuildContext context) {
    final filter = widget.filter;
    final pending = ref.watch(syncPendingStateProvider);
    final dirty = ref.watch(syncDirtyDiaryIdsProvider);
    final provider = diaryControllerProvider(
      categoryId: filter.categoryId,
      uncategorized: filter.uncategorized,
      tagName: filter.tagName,
    );
    final diaryAsync = ref.watch(provider);
    final selection = ref.watch(diarySelectionProvider);
    final selecting = selection.isNotEmpty;

    return diaryAsync.buildLoading(
      data: (page) {
        final diaries = page.items;
        if (!diaryAsync.isLoading) commitQuery(filter, page.sort);
        final showFooter =
            !diaryAsync.isLoading &&
            (page.isLoadingMore || page.loadMoreError != null);
        Future<bool> loadMore() => ref.read(provider.notifier).loadMore();
        final Widget content;
        if (diaries.isEmpty && !page.hasMore) {
          content = SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text(context.l10n.diary.tabViewEmpty)),
          );
        } else {
          final selNotifier = ref.read(diarySelectionProvider.notifier);
          content = SliverPadding(
            padding: .fromLTRB(
              0,
              8,
              0,
              12 + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverList.separated(
              itemCount: diaries.length + (showFooter ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index == diaries.length) {
                  return PaginationFooter(
                    onRetry: page.loadMoreError == null ? null : loadMore,
                  );
                }
                final diary = diaries[index];
                final syncState =
                    (pending.updateDiaryIds.contains(diary.id) ||
                        pending.newDiaryIds.contains(diary.id))
                    ? DiaryCardSyncState.syncing
                    : dirty.contains(diary.id)
                    ? DiaryCardSyncState.dirty
                    : DiaryCardSyncState.none;
                return Consumer(
                  builder: (context, ref, _) {
                    final category = ref.watch(
                      categoryByIdProvider(diary.categoryId),
                    );
                    final place = ref.watch(placeByIdProvider(diary.placeId));
                    return DiaryFeedTile(
                      key: ValueKey(diary.id),
                      diary: diary,
                      sort: page.sort,
                      category: category,
                      place: place,
                      showCategoryLabel: filter.isAll,
                      syncState: syncState,
                      selecting: selecting,
                      selected: selection.contains(diary.id),
                      onTap: selecting
                          ? () => selNotifier.toggle(diary.id)
                          : () => openDiaryDetail(context, diary),
                      onLongPress: selecting
                          ? null
                          : () => selNotifier.enter(diary.id),
                    );
                  },
                );
              },
            ),
          );
        }
        final showSummary =
            filter.isAll &&
            (pending.newDiaryIds.isNotEmpty ||
                pending.updateDiaryIds.isNotEmpty);
        return Column(
          children: [
            if (showSummary)
              Padding(
                padding: const .fromLTRB(12, 12, 12, 0),
                child: SyncPendingSummaryCard(
                  newCount: pending.newDiaryIds.length,
                  updateCount: pending.updateDiaryIds.length,
                  label: (newCount, updateCount) =>
                      context.l10n.sync.pendingSummary(
                        parts: [
                          if (newCount > 0)
                            context.l10n.sync.pendingNew(count: newCount),
                          if (updateCount > 0)
                            context.l10n.sync.pendingUpdate(count: updateCount),
                        ].join(' · '),
                      ),
                ),
              ),
            Expanded(
              child: MRefresh(
                paginationKey: (filter, page.sort),
                onRefresh: widget.onRefresh,
                refreshEnabled: widget.refreshEnabled,
                refreshLabels: widget.refreshLabels,
                onLoadMore: page.hasMore && !showFooter && !diaryAsync.isLoading
                    ? loadMore
                    : null,
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [content],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
