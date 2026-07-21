import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary/moodiary_diary.dart';
import 'package:moodiary_sync/moodiary_sync.dart';
import 'package:moodiary_editor/moodiary_editor.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_router/moodiary_router.dart';

/// 移动端首页壳（app 侧组合面）：把 moodiary_diary 的视图主体与 moodiary_sync 的
/// [SyncStatusButton]、新建日记 FAB 焊到一起。这是 diary↔sync 的唯一相遇处，故留在
/// app 侧、不入包。
class _DiaryListView extends ConsumerStatefulWidget {
  final bool showFab;

  const _DiaryListView({required this.showFab});

  @override
  ConsumerState<_DiaryListView> createState() => _DiaryListViewState();
}

class _DiaryListViewState extends ConsumerState<_DiaryListView> {
  String? _selectedCategoryId;

  void _onCategorySelected(String? categoryId) {
    if (categoryId == _selectedCategoryId) return;
    setState(() => _selectedCategoryId = categoryId);
  }

  Future<void> _openSwitcher() async {
    final result = await CategorySwitcherSheet.show(
      context,
      selectedId: _selectedCategoryId,
    );
    if (result == null || !mounted) return;
    _onCategorySelected(result.categoryId);
  }

  Widget _buildDiaryView() {
    return ValueListenableBuilder(
      valueListenable: MoodiaryKVs.homeViewMode.getNotifier(),
      builder: (context, viewMode, _) {
        return ValueListenableBuilder(
          valueListenable: MoodiaryKVs.homeSortMode.getNotifier(),
          builder: (context, sortMode, _) {
            final viewModeType = ViewModeType.getType(viewMode);
            final categoryId = _selectedCategoryId;
            return AnimatedSwitcher(
              duration: Durations.short3,
              child: KeyedSubtree(
                key: ValueKey('$viewMode-$sortMode-$categoryId'),
                child: switch (viewModeType) {
                  ViewModeType.list => DiaryListView(categoryId: categoryId),
                  ViewModeType.grid => DiaryWaterFallView(
                    categoryId: categoryId,
                  ),
                  ViewModeType.calendar => CalendarView(categoryId: categoryId),
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

    ref.listen(orderedCategoriesProvider, (_, next) {
      final id = _selectedCategoryId;
      final categories = next.value;
      if (id == null || categories == null) return;
      if (!categories.any((c) => c.id == id)) {
        setState(() => _selectedCategoryId = null);
        ref.read(diarySelectionProvider.notifier).clear();
        toast.info(message: context.l10n.categoryDeletedReset);
      }
    });

    Widget body = Column(
      children: [
        AnimatedOpacity(
          opacity: selecting ? 0.4 : 1,
          duration: Durations.short3,
          child: IgnorePointer(
            ignoring: selecting,
            child: CategoryFilterBar(
              selectedId: _selectedCategoryId,
              onSelected: _onCategorySelected,
              onOpenSwitcher: _openSwitcher,
            ),
          ),
        ),
        Expanded(child: _buildDiaryView()),
      ],
    );
    if (widget.showFab) {
      // 为底部 FAB 让出滚动空间：往子树 MediaQuery 注入额外底部留白，列表据此补 padding。
      final mq = MediaQuery.of(context);
      body = MediaQuery(
        data: mq.copyWith(
          padding: mq.padding.copyWith(bottom: mq.padding.bottom + 80),
        ),
        child: body,
      );
    }
    return PopScope(
      // 多选态：返回键先退出多选，而非离开首页。
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(diarySelectionProvider.notifier).clear();
      },
      child: Scaffold(
        appBar: selecting
            ? _selectionAppBar(context, selection.length)
            : _normalAppBar(context),
        floatingActionButton: (widget.showFab && !selecting)
            ? FloatingActionButton(
                // 唯一 heroTag：底部导航 IndexedStack 里本页与助手页 FAB 同时存活，
                // 默认 tag 相同会触发「multiple heroes share the same tag」。
                heroTag: 'diaryHomeFab',
                tooltip: context.l10n.homePageAddDiaryButton,
                onPressed: () => openNewDiaryEditor(
                  context,
                  DiaryType.tiptap,
                  categoryId: _selectedCategoryId,
                ),
                child: const Icon(Icons.add),
              )
            : null,
        body: body,
      ),
    );
  }

  PreferredSizeWidget _selectionAppBar(BuildContext context, int count) {
    return AppBar(
      leading: IconButton(
        tooltip: '取消',
        icon: const Icon(Icons.close_rounded),
        onPressed: () => ref.read(diarySelectionProvider.notifier).clear(),
      ),
      title: Text('已选 $count'),
      actions: [
        IconButton(
          tooltip: '删除',
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: count == 0 ? null : _deleteSelected,
        ),
      ],
    );
  }

  PreferredSizeWidget _normalAppBar(BuildContext context) {
    return AppBar(
      title: Text(context.l10n.appName),
      actions: [
        IconButton(
          tooltip: context.l10n.diarySearch,
          icon: const Icon(Icons.search_rounded),
          onPressed: () => const DiarySearchRoute().push(context),
        ),
        IconButton(
          tooltip: context.l10n.knowledgeGraph,
          icon: const Icon(Icons.hub_rounded),
          onPressed: () => const DiaryGraphRoute().push(context),
        ),
        const SyncStatusButton(),
        ValueListenableBuilder(
          valueListenable: MoodiaryKVs.homeViewMode.getNotifier(),
          builder: (context, homeViewMode, _) {
            final viewModeType = ViewModeType.getType(homeViewMode);
            return IconButton(
              tooltip: context.l10n.diaryPageViewModeButton,
              icon: Icon(switch (viewModeType) {
                ViewModeType.list => Icons.view_list_rounded,
                ViewModeType.grid => Icons.grid_view_rounded,
                ViewModeType.calendar => Icons.calendar_month_rounded,
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除所选日记？'),
        content: Text('已选 ${ids.length} 篇，将移入回收站，可在回收站恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final n = await ref
        .read(diaryControllerProvider(categoryId: _selectedCategoryId).notifier)
        .softDeleteByIds(ids);
    if (!mounted) return;
    ref.read(diarySelectionProvider.notifier).clear();
    toast.success(message: '已移入回收站（$n 篇）');
  }
}

/// 移动端：详情路由是顶层兄弟，push 落 root navigator 全屏盖过 shell，故本页只渲染
/// 列表，不涉及内层 navigator。
class DiaryHomePage extends StatelessWidget {
  const DiaryHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DiaryListView(showFab: true);
  }
}
