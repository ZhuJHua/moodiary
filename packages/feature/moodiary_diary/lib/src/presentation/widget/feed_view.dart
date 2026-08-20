/// @docImport 'package:moodiary_diary/src/application/diary_stamp.dart';
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary/src/application/diary_filter.dart';
import 'package:moodiary_diary/src/application/diary_selection.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_nav.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_tile_frame.dart';
import 'package:moodiary_diary/src/presentation/widget/feed_tile.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

/// 信息流视图：没有左栏、没有卡片，单图不占整行。
///
/// 与时间线不同，这里**不分组**，所以不受「分组键必须等于排序键」的约束。但行内显示的
/// 时间戳仍必须跟着排序键走（见 [diaryStampOf]）——否则按「最近修改」排序时，
/// 列表顺序按 lastModified、行里却写着 time，看起来就是一列日期无序的条目。
class DiaryFeedView extends ConsumerWidget {
  final DiaryFilter filter;

  const DiaryFeedView({super.key, this.filter = const .all()});

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
              final selNotifier = ref.read(diarySelectionProvider.notifier);
              final sort = DiarySort.getType(MoodiaryKVs.homeSortMode.get()!);
              body = MRefresh(
                onLoadMore: () => ref.read(provider.notifier).loadMore(),
                onRefresh: () => ref.read(provider.notifier).refresh(),
                child: ListView.separated(
                  padding: .fromLTRB(
                    0,
                    8,
                    0,
                    12 + MediaQuery.paddingOf(context).bottom,
                  ),
                  itemCount: diaries.length,
                  // 条目之间只留间距：分隔线会把整页压成一张表格，卡片自己的
                  // 边界已经说清楚「这里换了一条」。
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final diary = diaries[index];
                    final syncState = pending.updateDiaryIds.contains(diary.id)
                        ? DiaryCardSyncState.syncing
                        : dirty.contains(diary.id)
                        ? DiaryCardSyncState.dirty
                        : DiaryCardSyncState.none;
                    return Consumer(
                      builder: (context, ref, _) {
                        final category = ref.watch(
                          categoryByIdProvider(diary.categoryId),
                        );
                        return DiaryFeedTile(
                          // 按日记 id 定身份：列表按 index 复用 Element，重排后
                          // 缩略图（gaplessPlayback）会先画上一篇的照片。
                          key: ValueKey(diary.id),
                          diary: diary,
                          sort: sort,
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
