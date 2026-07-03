import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_card.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_nav.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';

class DiaryListView extends ConsumerWidget {
  final String? categoryId;

  const DiaryListView({super.key, required this.categoryId});

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
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    12,
                    12,
                    12 + MediaQuery.paddingOf(context).bottom,
                  ),
                  itemBuilder: (context, index) {
                    final diary = diaries[index];
                    final tile = Consumer(
                      builder: (context, ref, _) {
                        final category = ref.watch(
                          categoryByIdProvider(diary.categoryId),
                        );
                        return DiaryListTile(
                          diary: diary,
                          category: category,
                          showCategoryLabel: categoryId == null,
                          onTap: () => openDiaryDetail(context, diary),
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
                  separatorBuilder: (_, _) => const SizedBox(height: 8.0),
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
