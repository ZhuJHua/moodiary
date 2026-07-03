import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary/feature/calendar/presentation/calendar_page.dart';
import 'package:moodiary/feature/diary/application/category_controller.dart';
import 'package:moodiary/feature/diary/presentation/widget/sync_pending_indicator.dart';
import 'package:moodiary/feature/sync/application/sync_controller.dart';
import 'package:moodiary/feature/sync/presentation/widget/sync_status_sheet.dart';
import 'package:moodiary/feature/diary/presentation/widget/listview.dart';
import 'package:moodiary/feature/diary/presentation/widget/view_mode_sheet.dart';
import 'package:moodiary/feature/diary/presentation/widget/waterfall_view.dart';
import 'package:moodiary/feature/edit/presentation/widget/draft_prompt.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_router/moodiary_router.dart';

enum _HomeSection { all, category }

class _DiaryListView extends ConsumerStatefulWidget {
  final bool showFab;

  const _DiaryListView({required this.showFab});

  @override
  ConsumerState<_DiaryListView> createState() => _DiaryListViewState();
}

class _DiaryListViewState extends ConsumerState<_DiaryListView> {
  final PageController _pageController = PageController();
  _HomeSection _section = _HomeSection.all;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onSectionSelected(_HomeSection next) {
    if (next == _section) return;
    setState(() => _section = next);
    _pageController.animateToPage(
      next.index,
      duration: Durations.medium2,
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index) {
    final next = _HomeSection.values[index];
    if (next == _section) return;
    setState(() => _section = next);
  }

  Widget _buildAllDiaryView() {
    return ValueListenableBuilder(
      valueListenable: MoodiaryKVs.homeViewMode.getNotifier(),
      builder: (context, viewMode, _) {
        final viewModeType = ViewModeType.getType(viewMode);
        return AnimatedSwitcher(
          duration: Durations.short3,
          child: switch (viewModeType) {
            ViewModeType.list => const DiaryListView(categoryId: null),
            ViewModeType.grid => const DiaryWaterFallView(categoryId: null),
            ViewModeType.calendar => const CalendarView(),
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body = PageView(
      controller: _pageController,
      onPageChanged: _onPageChanged,
      children: [_buildAllDiaryView(), const _CategorySectionView()],
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
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: SegmentedButton<_HomeSection>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: Theme.of(context).textTheme.labelLarge,
          ),
          segments: [
            ButtonSegment(
              value: _HomeSection.all,
              label: Text(context.l10n.categoryAll),
            ),
            const ButtonSegment(
              value: _HomeSection.category,
              label: Text('分类'),
            ),
          ],
          selected: {_section},
          onSelectionChanged: (selection) =>
              _onSectionSelected(selection.first),
        ),
        actions: [
          IconButton(
            tooltip: context.l10n.diarySearch,
            icon: const Icon(Icons.search_rounded),
            onPressed: () => const DiarySearchRoute().push(context),
          ),
          Consumer(
            builder: (context, ref, _) {
              final running =
                  ref.watch(syncControllerProvider) is SyncRunning;
              return IconButton(
                tooltip: running ? '正在同步' : '同步状态',
                icon: running
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded),
                onPressed: () => showSyncStatusSheet(context),
              );
            },
          ),
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
      ),
      floatingActionButton: widget.showFab
          ? FloatingActionButton(
              tooltip: context.l10n.homePageAddDiaryButton,
              onPressed: () => openNewDiaryEditor(context, DiaryType.tiptap),
              child: const Icon(Icons.add),
            )
          : null,
      body: body,
    );
  }
}

/// 移动端：详情路由是 [StatefulShellRoute] 顶层兄弟，push 落 root navigator 全屏
/// 盖过 shell，故本页只渲染列表，不涉及内层 navigator。
class DiaryListPageMobile extends StatelessWidget {
  const DiaryListPageMobile({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DiaryListView(showFab: true);
  }
}

class _CategorySectionView extends ConsumerWidget {
  const _CategorySectionView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryAsync = ref.watch(categoryControllerProvider);
    return categoryAsync.buildLoading(
      data: (categories) {
        return ValueListenableBuilder(
          valueListenable: SyncPendingTracker.instance.listenable,
          builder: (context, pending, _) {
            // 远端将新增的分类排在已有分类之后占位，落库后由事件流原地替换。
            final placeholderCount = pending.newCategoryIds.length;
            if (categories.isEmpty && placeholderCount == 0) {
              return Center(
                child: Text(
                  '暂无分类',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              );
            }
            return ListView.separated(
              padding: EdgeInsets.fromLTRB(
                0,
                8,
                0,
                8 + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: categories.length + placeholderCount,
              separatorBuilder: (_, _) => const Divider(height: 0),
              itemBuilder: (context, index) {
                if (index >= categories.length) {
                  return const _CategoryPendingRow();
                }
                final category = categories[index];
                return _CategoryRow(
                  category: category,
                  syncing: pending.updateCategoryIds.contains(category.id),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final Category category;

  final bool syncing;

  const _CategoryRow({required this.category, this.syncing = false});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.label_outline_rounded),
      title: Text(category.categoryName),
      trailing: syncing
          ? const SyncPendingBadge()
          : const Icon(Icons.chevron_right_rounded),
      onTap: () {
        // TODO: 点击分类后的行为待定
      },
    );
  }
}

class _CategoryPendingRow extends StatelessWidget {
  const _CategoryPendingRow();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return ListTile(
      leading: Icon(Icons.label_outline_rounded, color: scheme.outline),
      title: Text(
        '正在同步分类…',
        style: context.textTheme.bodyMedium?.copyWith(color: scheme.outline),
      ),
      trailing: const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      ),
    );
  }
}
