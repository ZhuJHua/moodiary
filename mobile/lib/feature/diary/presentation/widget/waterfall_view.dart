import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary/feature/diary/application/category_controller.dart';
import 'package:moodiary/feature/diary/application/diary_controller.dart';
import 'package:moodiary/feature/diary/presentation/widget/diary_card.dart';
import 'package:moodiary/feature/diary/presentation/widget/sync_pending_indicator.dart';
import 'package:moodiary/feature/sync/data/sync_pending.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

class DiaryWaterFallView extends ConsumerWidget {
  final String? categoryId;

  const DiaryWaterFallView({super.key, this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = diaryControllerProvider(categoryId: categoryId);
    final diaryAsync = ref.watch(provider);

    return diaryAsync.buildLoading(
      data: (diaries) {
        return ListenableBuilder(
          listenable: Listenable.merge([
            SyncPendingTracker.instance.listenable,
            SyncDirtyTracker.instance.listenable,
          ]),
          builder: (context, _) {
            final pending = SyncPendingTracker.instance.listenable.value;
            final dirty = SyncDirtyTracker.instance.listenable.value;
            Widget body;
            if (diaries.isEmpty) {
              body = Center(child: Text(context.l10n.diaryTabViewEmpty));
            } else {
              body = MoodiaryRefresh(
                onLoading: () => ref.read(provider.notifier).loadMore(),
                onRefresh: () => ref.read(provider.notifier).refresh(),
                child: WaterfallFlow.builder(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    12,
                    12,
                    12 + MediaQuery.paddingOf(context).bottom,
                  ),
                  gridDelegate:
                      const SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 250,
                        mainAxisSpacing: 8.0,
                        crossAxisSpacing: 8.0,
                      ),
                  itemBuilder: (context, index) {
                    final diary = diaries[index];
                    final tile = Consumer(
                      builder: (context, ref, _) {
                        final category = ref.watch(
                          categoryByIdProvider(diary.categoryId),
                        );
                        return DiaryGridTile(
                          diary: diary,
                          category: category,
                          showCategoryLabel: categoryId == null,
                        );
                      },
                    );
                    final syncing = pending.updateDiaryIds.contains(diary.id);
                    final dirtyBadge = !syncing && dirty.contains(diary.id);
                    if (!syncing && !dirtyBadge) return tile;
                    return Stack(
                      children: [
                        tile,
                        Positioned(
                          top: 8,
                          right: 8,
                          child: syncing
                              ? const SyncPendingBadge()
                              : const SyncDirtyBadge(),
                        ),
                      ],
                    );
                  },
                  itemCount: diaries.length,
                ),
              );
            }
            // 聚合提示卡只进「全部」视图（全局数量）。
            final showSummary =
                categoryId == null &&
                (pending.newDiaryIds.isNotEmpty ||
                    pending.updateDiaryIds.isNotEmpty);
            if (!showSummary) return body;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: SyncPendingSummaryCard(
                    newCount: pending.newDiaryIds.length,
                    updateCount: pending.updateDiaryIds.length,
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
