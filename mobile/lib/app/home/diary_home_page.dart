import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_diary/moodiary_diary.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_sync/moodiary_sync.dart';
import 'package:mui/mui.dart';

class _DiaryListView extends ConsumerStatefulWidget {
  final VoidCallback? onOpenDrawer;

  const _DiaryListView({this.onOpenDrawer});

  @override
  ConsumerState<_DiaryListView> createState() => _DiaryListViewState();
}

class _DiaryListViewState extends ConsumerState<_DiaryListView> {
  Widget _buildDiaryView(DiaryFilter filter) {
    return ValueListenableBuilder(
      valueListenable: MoodiaryKVs.homeViewMode.getNotifier(),
      builder: (context, viewMode, _) {
        return ValueListenableBuilder(
          valueListenable: MoodiaryKVs.homeSortMode.getNotifier(),
          builder: (context, sortMode, _) {
            final viewModeType = ViewModeType.getType(viewMode);
            final sort = DiarySort.getType(sortMode);
            return AnimatedSwitcher(
              duration: Durations.short3,
              child: KeyedSubtree(
                key: ValueKey('$viewMode-$sortMode-$filter'),
                child: switch (viewModeType) {
                  .timeline => DiaryTimelineView(filter: filter, sort: sort),
                  .feed => DiaryFeedView(filter: filter, sort: sort),
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(diarySelectionProvider);
    final selecting = selection.isNotEmpty;
    final filter = ref.watch(homeDiaryFilterProvider);

    ref.listen(orderedCategoriesProvider, (_, next) {
      final id = ref.read(homeDiaryFilterProvider).categoryId;
      final categories = next.value;
      if (id == null || categories == null) return;
      if (!categories.any((c) => c.id == id)) {
        ref.read(homeDiaryFilterProvider.notifier).reset();
        ref.read(diarySelectionProvider.notifier).clear();
        toast.info(message: context.l10n.app.categoryDeletedReset);
      }
    });

    final body = _buildDiaryView(filter);
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(diarySelectionProvider.notifier).clear();
      },
      child: Scaffold(
        appBar: selecting
            ? _selectionAppBar(context, selection.length)
            : _normalAppBar(context, filter),
        body: body,
      ),
    );
  }

  PreferredSizeWidget _selectionAppBar(BuildContext context, int count) {
    return AppBar(
      leading: IconButton(
        tooltip: context.l10n.common.cancel,
        icon: const Icon(LucideIcons.x),
        onPressed: () => ref.read(diarySelectionProvider.notifier).clear(),
      ),
      title: Text(context.l10n.app.homeSelected(count: count)),
      actions: [
        IconButton(
          tooltip: context.l10n.common.delete,
          icon: const Icon(LucideIcons.trash2),
          onPressed: count == 0 ? null : _deleteSelected,
        ),
      ],
    );
  }

  PreferredSizeWidget _normalAppBar(BuildContext context, DiaryFilter filter) {
    return AppBar(
      leadingWidth: 52,
      leading: ValueListenableBuilder(
        valueListenable: getIt<SyncPendingTracker>().listenable,
        builder: (context, pending, _) => IconButton(
          tooltip: context.l10n.diary.allCategories,
          onPressed: widget.onOpenDrawer,
          icon: Badge(
            isLabelVisible: pending.newCategoryIds.isNotEmpty,
            smallSize: 7,
            child: const Icon(LucideIcons.menu),
          ),
        ),
      ),
      titleSpacing: 0,
      title: _FilterTitle(filter: filter),
      actions: [
        IconButton(
          tooltip: context.l10n.diary.search,
          icon: const Icon(LucideIcons.search),
          onPressed: () => const DiarySearchRoute().push(context),
        ),
        const SyncStatusButton(),
        ValueListenableBuilder(
          valueListenable: MoodiaryKVs.homeViewMode.getNotifier(),
          builder: (context, homeViewMode, _) {
            final viewModeType = ViewModeType.getType(homeViewMode);
            return IconButton(
              tooltip: context.l10n.diary.pageViewModeButton,
              icon: Icon(switch (viewModeType) {
                .timeline => LucideIcons.gitCommitVertical,
                .feed => LucideIcons.layoutList,
              }),
              onPressed: () => ViewModeSheet.show(context),
            );
          },
        ),
      ],
    );
  }

  Future<void> _deleteSelected() async {
    final ids = ref.read(diarySelectionProvider);
    if (ids.isEmpty) return;
    final confirmed = await MAlert.confirm(
      context,
      title: l10n.app.homeDeleteTitle,
      message: l10n.app.homeDeleteMessage(count: ids.length),
      confirmLabel: l10n.common.delete,
      isDestructive: true,
    );
    if (!confirmed) return;
    final filter = ref.read(homeDiaryFilterProvider);
    final n = await ref
        .read(
          diaryControllerProvider(
            categoryId: filter.categoryId,
            uncategorized: filter.uncategorized,
          ).notifier,
        )
        .softDeleteByIds(ids);
    if (!mounted) return;
    ref.read(diarySelectionProvider.notifier).clear();
    if (n == 0) {
      toast.info(message: l10n.app.homeNothingToDelete);
    } else {
      toast.success(message: l10n.app.homeMovedToRecycle(count: n));
    }
  }
}

class _FilterTitle extends ConsumerWidget {
  final DiaryFilter filter;

  const _FilterTitle({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.theme.colors;
    final counts = ref.watch(categoryDiaryCountsProvider).value;
    final category = filter.categoryId == null
        ? null
        : ref.watch(categoryByIdProvider(filter.categoryId));

    final (String label, Color? dot, int? count) = switch (filter) {
      _ when filter.isAll => (context.l10n.common.appName, null, null),
      _ when filter.uncategorized => (
        context.l10n.diary.categoryNoCategory,
        null,
        counts == null
            ? null
            : counts.total -
                  counts.byCategory.values.fold<int>(0, (a, b) => a + b),
      ),
      _ => (
        category?.categoryName ?? context.l10n.common.appName,
        category == null
            ? null
            : categoryColorOf(colorValue: category.color, id: category.id),
        counts?.byCategory[filter.categoryId],
      ),
    };

    return Row(
      mainAxisSize: .min,
      children: [
        if (dot != null) ...[
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: dot, shape: .circle),
          ),
          const SizedBox(width: 8),
        ] else if (filter.uncategorized) ...[
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: .circle,
              border: .all(color: scheme.outline, width: 1.4),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(child: Text(label, maxLines: 1, overflow: .ellipsis)),
        if (count != null) ...[
          const SizedBox(width: 8),
          Text(
            context.l10n.diary.searchResult(count: count),
            style: context.theme.typography.labelSmall.onSurfaceVariant,
          ),
        ],
      ],
    );
  }
}

class DiaryHomePage extends StatelessWidget {
  final VoidCallback? onOpenDrawer;

  const DiaryHomePage({super.key, this.onOpenDrawer});

  @override
  Widget build(BuildContext context) {
    return _DiaryListView(onOpenDrawer: onOpenDrawer);
  }
}
