import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_diary/moodiary_diary.dart';
import 'package:moodiary_sync/moodiary_sync.dart';
import 'package:moodiary_editor/moodiary_editor.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_router/moodiary_router.dart';

/// 移动端首页壳（app 侧组合面）：把 moodiary_diary 的视图主体（全部日记 / 分类分区）
/// 与 moodiary_sync 的 [SyncStatusButton]、新建日记 FAB 焊到一个分段式 AppBar 里。
/// 这是 diary↔sync 的唯一相遇处，故留在 app 侧、不入包。
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
      children: [_buildAllDiaryView(), const DiaryCategorySectionView()],
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

/// 移动端：详情路由是顶层兄弟，push 落 root navigator 全屏盖过 shell，故本页只渲染
/// 列表，不涉及内层 navigator。
class DiaryHomePage extends StatelessWidget {
  const DiaryHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DiaryListView(showFab: true);
  }
}
