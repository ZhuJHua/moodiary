import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
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

/// 时间线视图：左侧一条真正的轴——圆点与线段都取心情色，滑动即读一段情绪走向。
///
/// 分组键必须等于排序键（见 [diaryStampOf]），否则按「最近修改」排序时月份吸顶头
/// 会重复且乱序。分组本身是对**已加载前缀**的纯函数（[buildTimeline]），分页续加和
/// 同步回写触发的重排都只是重新算一遍。
class DiaryTimelineView extends ConsumerWidget {
  final DiaryFilter filter;

  /// 排序是显式参数而非命令式读全局 KV——本 widget 是包的公开 API，正确性
  /// 不能挂在「宿主会在 sort 变化时换 key 重建」这种写不进类型的契约上。
  final DiarySort sort;

  const DiaryTimelineView({super.key, this.filter = const .all(), this.sort = .timeDesc});

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
            SyncPendingTracker.instance.listenable,
            SyncDirtyTracker.instance.listenable,
          ]),
          builder: (context, _) {
            final pending = SyncPendingTracker.instance.listenable.value;
            final dirty = SyncDirtyTracker.instance.listenable.value;
            Widget body;
            if (diaries.isEmpty) {
              body = Center(child: Text(context.l10n.diary.tabViewEmpty));
            } else {
              // 篇数走独立聚合查询：列表分页加载，从中数只能数出「加载到哪儿了」。
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
                slivers.add(
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _MonthHeaderDelegate(
                      month: month.month,
                      count: monthCounts?[month.month],
                    ),
                  ),
                );
                slivers.add(
                  SliverList.builder(
                    itemCount: month.entries.length,
                    itemBuilder: (context, index) {
                      final flatIndex = base + index;
                      final entry = flat[flatIndex];
                      final diary = entry.diary;
                      final syncState =
                          pending.updateDiaryIds.contains(diary.id)
                          ? DiaryCardSyncState.syncing
                          : dirty.contains(diary.id)
                          ? DiaryCardSyncState.dirty
                          : DiaryCardSyncState.none;
                      return Consumer(
                        builder: (context, ref, _) {
                          final category = ref.watch(
                            categoryByIdProvider(diary.categoryId),
                          );
                          final next = flatIndex == flat.length - 1
                              ? null
                              : flat[flatIndex + 1];
                          return DiaryTimelineTile(
                            // 按日记 id 定身份：列表按 index 复用 Element，重排后
                            // 缩略图（gaplessPlayback）会先画上一篇的照片。
                            key: ValueKey(diary.id),
                            diary: diary,
                            stamp: entry.stamp,
                            dayStart: entry.dayStart,
                            breakBefore: entry.breakBefore,
                            breakAfter: next?.breakBefore ?? false,
                            hasAbove: flatIndex > 0,
                            moodBelow: next?.diary.mood,
                            category: category,
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
                    // 左右留白统一加在这里：吸顶头与条目必须同一条左边线，
                    // 否则轴心 x 会跟着差 14px。
                    SliverPadding(
                      padding: const .symmetric(horizontal: 14),
                      sliver: SliverMainAxisGroup(slivers: slivers),
                    ),
                  ],
                ),
              );
            }
            // 聚合提示卡只进「全部」视图（全局数量）。
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

/// 月份吸顶头。篇数由 [timelineMonthCounts] 聚合查询提供（不是数已加载的列表），
/// 查询回来之前为 null —— 宁可先不显示，也不要先显示一个会跳变的数。
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
