import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary/moodiary_diary.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_sync/moodiary_sync.dart';
import 'package:mui/mui.dart';

@visibleForTesting
String? resolveSelectedTagName(
  String name,
  Map<String, Tag> previous,
  Map<String, Tag> current,
) {
  if (current.values.any((tag) => !tag.deleted && tag.name == name)) {
    return name;
  }
  for (final tag in previous.values) {
    if (tag.deleted || tag.name != name) continue;
    if (current[tag.id] case Tag(deleted: false, name: final newName)) {
      return newName;
    }
  }
  return null;
}

class DiaryHomePage extends ConsumerStatefulWidget {
  final VoidCallback? onOpenDrawer;
  final bool Function()? isActiveTab;

  const DiaryHomePage({super.key, this.onOpenDrawer, this.isActiveTab});

  @override
  ConsumerState<DiaryHomePage> createState() => _DiaryHomePageState();
}

class _DiaryHomePageState extends ConsumerState<DiaryHomePage> {
  Map<String, Tag> _lastTags = const {};

  Future<MRefreshOutcome?> _pullToSync() async {
    final result = await triggerManualSync(
      context: context,
      ref: ref,
      canPrompt: () =>
          mounted &&
          (widget.isActiveTab?.call() ?? true) &&
          (ModalRoute.of(context)?.isCurrent ?? false),
    );
    return switch (result) {
      ManualSyncCompleted(:final outcome) => switch (outcome.kind) {
        .changed => MRefreshOutcome(
          status: .success,
          message: _changedMessage(outcome.report),
        ),
        .upToDate => MRefreshOutcome(message: l10n.sync.pullUpToDate),
        .partial => MRefreshOutcome(
          status: .warning,
          message: l10n.sync.pullPartial,
        ),
        .stopped => MRefreshOutcome(message: l10n.sync.pullStopped),
        .failed => MRefreshOutcome(
          status: .error,
          message: outcome.error?.kind.isUnreachable == true
              ? l10n.sync.pullUnreachable
              : l10n.sync.pullFailed,
        ),
      },
      ManualSyncBusy() => MRefreshOutcome(message: l10n.sync.pullBusy),
      ManualSyncCancelled() => null,
      ManualSyncUnreachable() => MRefreshOutcome(
        status: .error,
        message: l10n.sync.pullUnreachable,
      ),
      ManualSyncFailed() => MRefreshOutcome(
        status: .error,
        message: l10n.sync.pullFailed,
      ),
    };
  }

  String _changedMessage(SyncReport? report) {
    final changes = report == null
        ? SyncCounts.zero
        : report.pushed + report.pulled;
    final count =
        changes.diaries +
        changes.categories +
        changes.tags +
        changes.places +
        changes.mediaFiles;
    return count == 0
        ? l10n.sync.pullSynced
        : l10n.sync.pullSyncedCount(count: count);
  }

  Widget _buildDiaryView(DiaryFilter filter) {
    final mode = ref.watch(kvValueProvider(MoodiaryKVs.homeViewMode));
    final ready = ref.watch(syncBackendReadyProvider);
    final onRefresh = switch (ready) {
      AsyncData(value: true, isLoading: false) => _pullToSync,
      _ => null,
    };
    final enabled = !ref.watch(syncOperationBusyProvider);
    final labels = MRefreshLabels(
      pull: context.l10n.sync.pullToSync,
      armed: context.l10n.sync.releaseToSync,
      loading: context.l10n.sync.statusRunning,
      complete: context.l10n.sync.pullUpToDate,
    );
    return AnimatedSwitcher(
      duration: Durations.short3,
      child: switch (ViewModeType.getType(mode)) {
        .timeline => DiaryTimelineView(
          filter: filter,
          onRefresh: onRefresh,
          refreshEnabled: enabled,
          refreshLabels: labels,
        ),
        .feed => DiaryFeedView(
          filter: filter,
          onRefresh: onRefresh,
          refreshEnabled: enabled,
          refreshLabels: labels,
        ),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selecting = ref.watch(
      diarySelectionProvider.select((selection) => selection.isNotEmpty),
    );
    final filter = ref.watch(homeDiaryFilterProvider);
    ref.listen(
      homeDiaryFilterProvider,
      (_, _) => ref.read(diarySelectionProvider.notifier).clear(),
    );
    ref.listen(
      kvValueProvider(MoodiaryKVs.homeSortMode),
      (_, _) => ref.read(diarySelectionProvider.notifier).clear(),
    );

    // Keep editor metadata warm while the home route remains mounted.
    ref.listen(orderedPlacesProvider, (_, _) {});
    ref.listen(secretKvProvider(MoodiarySecureKVs.qweatherKey), (_, _) {});

    ref.listen(orderedCategoriesProvider, (_, next) {
      final id = ref.read(homeDiaryFilterProvider).categoryId;
      final categories = next.value;
      if (id == null || categories == null) return;
      if (!categories.any((c) => c.id == id)) {
        ref.read(homeDiaryFilterProvider.notifier).reset();
        toast.info(message: l10n.app.categoryDeletedReset);
      }
    });

    if (filter.tagName != null) {
      _lastTags = ref.read(tagCatalogProvider).value?.byId ?? _lastTags;
      ref.listen(tagCatalogProvider, (_, next) {
        final name = ref.read(homeDiaryFilterProvider).tagName;
        if (name == null) return;
        if (next case AsyncData(:final value)) {
          final resolved = resolveSelectedTagName(name, _lastTags, value.byId);
          _lastTags = value.byId;
          if (resolved == name) return;
          if (resolved != null) {
            ref.read(homeDiaryFilterProvider.notifier).select(.tag(resolved));
            return;
          }
          ref.read(homeDiaryFilterProvider.notifier).reset();
          toast.info(message: l10n.app.tagFilterReset);
        }
      });
    }

    final body = _buildDiaryView(filter);
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(diarySelectionProvider.notifier).clear();
      },
      child: Scaffold(
        appBar: selecting
            ? _SelectionAppBar(onDelete: _deleteSelected)
            : _normalAppBar(context, filter),
        body: body,
      ),
    );
  }

  PreferredSizeWidget _normalAppBar(BuildContext context, DiaryFilter filter) {
    final viewModeType = ViewModeType.getType(
      ref.watch(kvValueProvider(MoodiaryKVs.homeViewMode)),
    );
    return AppBar(
      leadingWidth: 52,
      leading: _DrawerMenuButton(onPressed: widget.onOpenDrawer),
      titleSpacing: 0,
      title: _FilterTitle(filter: filter),
      actions: [
        IconButton(
          tooltip: context.l10n.diary.search,
          icon: const Icon(LucideIcons.search),
          onPressed: () => const DiarySearchRoute().push(context),
        ),
        const SyncStatusButton(),
        IconButton(
          tooltip: context.l10n.diary.pageViewModeButton,
          icon: Icon(switch (viewModeType) {
            .timeline => LucideIcons.gitCommitVertical,
            .feed => LucideIcons.layoutList,
          }),
          onPressed: () => ViewModeSheet.show(context),
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
    if (!confirmed ||
        !mounted ||
        !identical(ref.read(diarySelectionProvider), ids)) {
      return;
    }
    final filter = ref.read(homeDiaryFilterProvider);
    final n = await ref
        .read(
          diaryControllerProvider(
            categoryId: filter.categoryId,
            uncategorized: filter.uncategorized,
            tagName: filter.tagName,
          ).notifier,
        )
        .softDeleteByIds(ids);
    if (!mounted) return;
    if (identical(ref.read(diarySelectionProvider), ids)) {
      ref.read(diarySelectionProvider.notifier).clear();
    }
    if (n == 0) {
      toast.info(message: l10n.app.homeNothingToDelete);
    } else {
      toast.success(message: l10n.app.homeMovedToRecycle(count: n));
    }
  }
}

class _SelectionAppBar extends ConsumerWidget implements PreferredSizeWidget {
  static final _preferredSize = AppBar().preferredSize;

  final VoidCallback onDelete;

  const _SelectionAppBar({required this.onDelete});

  @override
  Size get preferredSize => _preferredSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(diarySelectionProvider.select((s) => s.length));
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
          onPressed: count == 0 ? null : onDelete,
        ),
      ],
    );
  }
}

class _DrawerMenuButton extends ConsumerWidget {
  final VoidCallback? onPressed;

  const _DrawerMenuButton({required this.onPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPending = ref.watch(
      syncPendingStateProvider.select((p) => p.newCategoryIds.isNotEmpty),
    );
    return IconButton(
      tooltip: context.l10n.diary.allCategories,
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: hasPending,
        smallSize: 7,
        child: const Icon(LucideIcons.menu),
      ),
    );
  }
}

class _FilterTitle extends ConsumerWidget {
  final DiaryFilter filter;

  const _FilterTitle({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.theme.colors;
    final (String label, Color? dot, int? count) = switch (filter) {
      _ when filter.isAll => (context.l10n.common.appName, null, null),
      DiaryFilter(tagName: final name?) => (
        name,
        null,
        ref
            .watch(tagCatalogProvider)
            .value
            ?.usage
            .where((tag) => tag.name == name)
            .firstOrNull
            ?.count,
      ),
      _ when filter.uncategorized => _uncategorizedTitle(context, ref),
      DiaryFilter(categoryId: final id?) => _categoryTitle(context, ref, id),
      _ => (context.l10n.common.appName, null, null),
    };

    return Row(
      mainAxisSize: .min,
      children: [
        if (filter.tagName != null) ...[
          Icon(LucideIcons.hash, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
        ] else if (dot != null) ...[
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

  (String, Color?, int?) _uncategorizedTitle(
    BuildContext context,
    WidgetRef ref,
  ) {
    final counts = ref.watch(categoryDiaryCountsProvider).value;
    return (
      context.l10n.diary.categoryNoCategory,
      null,
      counts == null
          ? null
          : counts.total -
                counts.byCategory.values.fold<int>(0, (a, b) => a + b),
    );
  }

  (String, Color?, int?) _categoryTitle(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) {
    final counts = ref.watch(categoryDiaryCountsProvider).value;
    final category = ref.watch(categoryByIdProvider(id));
    return (
      category?.categoryName ?? context.l10n.common.appName,
      category == null
          ? null
          : categoryColorOf(colorValue: category.color, id: category.id),
      counts?.byCategory[id],
    );
  }
}
