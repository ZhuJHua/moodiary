import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_diary/src/application/diary_filter.dart';
import 'package:moodiary_diary/src/application/diary_selection.dart';
import 'package:moodiary_diary/src/application/timeline_controller.dart';
import 'package:moodiary_diary/src/application/timeline_group.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_nav.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_tile_frame.dart';
import 'package:moodiary_diary/src/presentation/widget/timeline_tile.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

class DiaryTimelineView extends ConsumerWidget {
  final DiaryFilter filter;

  final DiarySort sort;

  const DiaryTimelineView({
    super.key,
    this.filter = const .all(),
    this.sort = .timeDesc,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = diaryControllerProvider(
      categoryId: filter.categoryId,
      uncategorized: filter.uncategorized,
    );
    final diaryAsync = ref.watch(provider);
    final selection = ref.watch(diarySelectionProvider);
    final selecting = selection.isNotEmpty;

    return diaryAsync.buildLoading(
      data: (diaries) {
        return ListenableBuilder(
          listenable: .merge([
            getIt<SyncPendingTracker>().listenable,
            getIt<SyncDirtyTracker>().listenable,
          ]),
          builder: (context, _) {
            final pending = getIt<SyncPendingTracker>().listenable.value;
            final dirty = getIt<SyncDirtyTracker>().listenable.value;
            Widget body;
            if (diaries.isEmpty) {
              body = Center(child: Text(context.l10n.diary.tabViewEmpty));
            } else {
              final monthCounts = ref
                  .watch(
                    timelineMonthCountsProvider(
                      categoryId: filter.categoryId,
                      uncategorized: filter.uncategorized,
                      sort: sort,
                    ),
                  )
                  .value;
              final months = buildTimeline(diaries, sort);
              final flat = [for (final m in months) ...m.entries];
              final selNotifier = ref.read(diarySelectionProvider.notifier);
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
                        final category = ref.watch(
                          categoryByIdProvider(diary.categoryId),
                        );
                        final place = ref.watch(
                          placeByIdProvider(diary.placeId),
                        );
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
                );
                slivers.add(SliverMainAxisGroup(slivers: [header, list]));
              }
              slivers.add(
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 24 + MediaQuery.paddingOf(context).bottom,
                  ),
                ),
              );

              body = MRefresh(
                onLoadMore: () => ref.read(provider.notifier).loadMore(),
                onRefresh: () => ref.read(provider.notifier).refresh(),
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const .symmetric(horizontal: 14),
                      sliver: SliverMainAxisGroup(slivers: slivers),
                    ),
                  ],
                ),
              );
            }
            final showSummary =
                filter.isAll &&
                (pending.newDiaryIds.isNotEmpty ||
                    pending.updateDiaryIds.isNotEmpty);
            if (!showSummary) return body;
            return Column(
              children: [
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
                              context.l10n.sync.pendingUpdate(
                                count: updateCount,
                              ),
                          ].join(' · '),
                        ),
                  ),
                ),
                Expanded(child: body),
              ],
            );
          },
        );
      },
    );
  }
}

class _MonthHeaderDelegate extends SliverPersistentHeaderDelegate {
  final DateTime month;
  final int? count;

  const _MonthHeaderDelegate({required this.month, required this.count});

  static const double _height = 34.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final colors = context.theme.colors;
    return Container(
      height: _height,
      alignment: .centerLeft,
      color: colors.surface,
      child: Row(
        children: [
          Text(
            TimeFormat.monthTitle(month),
            style: context.theme.typography.titleSmall.emphasized.onSurface,
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Text(
              context.l10n.diary.timelineMonthCount(count: count!),
              style: context.theme.typography.labelSmall.onSurfaceVariant,
            ),
          ],
          const SizedBox(width: 10),
          Expanded(child: Divider(height: 1, color: colors.outlineVariant)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _MonthHeaderDelegate old) =>
      old.month != month || old.count != count;
}
