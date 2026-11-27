library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary/src/presentation/controllers/diary_controller.dart';
import 'package:moodiary_diary/src/presentation/controllers/diary_filter.dart';
import 'package:moodiary_diary/src/presentation/controllers/diary_selection.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_nav.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_tile_frame.dart';
import 'package:moodiary_diary/src/presentation/widget/feed_tile.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

class DiaryFeedView extends ConsumerWidget {
  final DiaryFilter filter;

  const DiaryFeedView({super.key, this.filter = const .all()});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = DiarySort.getType(
      ref.watch(kvValueProvider(MoodiaryKVs.homeSortMode)),
    );
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
      skipLoadingOnReload: false,
      data: (diaries) {
        Widget body;
        if (diaries.isEmpty) {
          body = Center(child: Text(context.l10n.diary.tabViewEmpty));
        } else {
          final selNotifier = ref.read(diarySelectionProvider.notifier);
          body = MRefresh(
            onLoadMore: () => ref.read(provider.notifier).loadMore(),
            child: ListView.separated(
              padding: .fromLTRB(
                0,
                8,
                0,
                12 + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: diaries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
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
                    final place = ref.watch(placeByIdProvider(diary.placeId));
                    return DiaryFeedTile(
                      key: ValueKey(diary.id),
                      diary: diary,
                      sort: sort,
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
                          context.l10n.sync.pendingUpdate(count: updateCount),
                      ].join(' · '),
                    ),
              ),
            ),
            Expanded(child: body),
          ],
        );
      },
    );
  }
}
