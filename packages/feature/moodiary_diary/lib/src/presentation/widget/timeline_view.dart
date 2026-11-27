import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary/src/application/timeline_controller.dart';
import 'package:moodiary_diary/src/application/timeline_group.dart';
import 'package:moodiary_diary/src/presentation/controllers/diary_controller.dart';
import 'package:moodiary_diary/src/presentation/controllers/diary_filter.dart';
import 'package:moodiary_diary/src/presentation/controllers/diary_selection.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_card_parts.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_nav.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_page_scroll.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_tile_frame.dart';
import 'package:moodiary_diary/src/presentation/widget/timeline_tile.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

class DiaryTimelineView extends ConsumerStatefulWidget {
  final DiaryFilter filter;
  final MRefreshCallback? onRefresh;
  final bool refreshEnabled;
  final MRefreshLabels? refreshLabels;

  const DiaryTimelineView({
    super.key,
    this.filter = const .all(),
    this.onRefresh,
    this.refreshEnabled = true,
    this.refreshLabels,
  });

  @override
  ConsumerState<DiaryTimelineView> createState() => _DiaryTimelineViewState();
}

class _DiaryTimelineViewState extends ConsumerState<DiaryTimelineView>
    with DiaryPageScroll<DiaryTimelineView> {
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
          final monthCounts = ref
              .watch(
                timelineMonthCountsProvider(
                  categoryId: filter.categoryId,
                  uncategorized: filter.uncategorized,
                  tagName: filter.tagName,
                  sort: page.sort,
                ),
              )
              .value;
          final months = buildTimeline(diaries, page.sort);
          final flat = [for (final m in months) ...m.entries];
          final selNotifier = ref.read(diarySelectionProvider.notifier);
          final headerHeight =
              (diaryScaledLineHeight(
                        context,
                        context
                            .theme
                            .typography
                            .titleSmall
                            .emphasized
                            .onSurface,
                      ) +
                      14)
                  .clamp(34.0, double.infinity);
          var offset = 0;

          final slivers = <Widget>[];
          for (final month in months) {
            final base = offset;
            offset += month.entries.length;
            final header = SliverPersistentHeader(
              pinned: true,
              delegate: _MonthHeaderDelegate(
                month: month.month,
                count: monthCounts?[month.month],
                height: headerHeight,
              ),
            );
            final list = SliverList.builder(
              itemCount: month.entries.length,
              itemBuilder: (context, index) {
                final flatIndex = base + index;
                final entry = flat[flatIndex];
                final diary = entry.diary;
                final syncState =
                    (pending.updateDiaryIds.contains(diary.id) ||
                        pending.newDiaryIds.contains(diary.id))
                    ? DiaryCardSyncState.syncing
                    : dirty.contains(diary.id)
                    ? DiaryCardSyncState.dirty
                    : DiaryCardSyncState.none;
                return Consumer(
                  builder: (context, ref, _) {
                    final place = ref.watch(placeByIdProvider(diary.placeId));
                    final next = flatIndex == flat.length - 1
                        ? null
                        : flat[flatIndex + 1];
                    return DiaryTimelineTile(
                      key: ValueKey(diary.id),
                      diary: diary,
                      stamp: entry.stamp,
                      dayStart: entry.dayStart,
                      breakBefore: entry.breakBefore,
                      breakAfter: next?.breakBefore ?? false,
                      hasAbove: flatIndex > 0,
                      moodBelow: next?.diary.mood,
                      hasBelow: next != null,
                      place: place,
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
            );
            slivers.add(SliverMainAxisGroup(slivers: [header, list]));
          }
          if (showFooter) {
            slivers.add(
              SliverToBoxAdapter(
                child: PaginationFooter(
                  onRetry: page.loadMoreError == null ? null : loadMore,
                ),
              ),
            );
          }
          slivers.add(
            SliverToBoxAdapter(
              child: SizedBox(
                height: 24 + MediaQuery.paddingOf(context).bottom,
              ),
            ),
          );

          content = SliverPadding(
            padding: const .symmetric(horizontal: 14),
            sliver: SliverMainAxisGroup(slivers: slivers),
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

class _MonthHeaderDelegate extends SliverPersistentHeaderDelegate {
  final DateTime month;
  final int? count;
  final double height;

  const _MonthHeaderDelegate({
    required this.month,
    required this.count,
    required this.height,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      _MonthHeader(month: month, count: count, height: height);

  @override
  bool shouldRebuild(covariant _MonthHeaderDelegate old) =>
      old.month != month || old.count != count || old.height != height;
}

// 主题必须在子 Widget 里读：父级同帧重建时 header Element 的 dirty 会被
// update() 清掉而不重跑 delegate.build，切深浅色后吸顶头就停在旧配色。
class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final int? count;
  final double height;

  const _MonthHeader({
    required this.month,
    required this.count,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Semantics(
      header: true,
      child: Stack(
        clipBehavior: .none,
        children: [
          // 两个吸顶头交接在小数像素上，各自抗锯齿会透出上个月的时间轴。
          // 靠前的分组后画、压在上面，所以由它的底色整块向下多盖 1px 封住交接行。
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: -1,
            child: ColoredBox(color: colors.surface),
          ),
          Container(
            height: height,
            alignment: .centerLeft,
            child: Row(
              children: [
                Text(
                  TimeFormat.monthTitle(month),
                  style:
                      context.theme.typography.titleSmall.emphasized.onSurface,
                ),
                if (count != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.diary.timelineMonthCount(count: count!),
                    style: context.theme.typography.labelSmall.onSurfaceVariant
                        .copyWith(fontFeatures: const [.tabularFigures()]),
                  ),
                ],
                const SizedBox(width: 10),
                Expanded(
                  child: Divider(height: 1, color: colors.outlineVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
