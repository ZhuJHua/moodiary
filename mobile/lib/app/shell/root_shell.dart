import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:unicons/unicons.dart';
import 'package:moodiary_assistant/moodiary_assistant.dart'
    show AssistantSessionListPage;
import 'package:moodiary/app/home/diary_home_page.dart' show DiaryHomePage;
import 'package:moodiary_diary/moodiary_diary.dart'
    show CategoryDrawer, diarySelectionProvider, homeDiaryFilterProvider;
import 'package:moodiary_editor/moodiary_editor.dart' show openNewDiaryEditor;
import 'package:moodiary_media/moodiary_media.dart';
import 'package:moodiary_models/moodiary_models.dart' show DiaryType;
import 'package:moodiary_ui/moodiary_ui.dart'
    show MoodiaryNavAction, MoodiaryNavBar, MoodiaryNavDestination;

/// 三个 tab —— 设置不在这儿，入口在分类抽屉底部（胶囊只装得下三个，加上右边那颗
/// 创建按钮正好一行）。
List<MoodiaryNavDestination> _navDestinations(BuildContext context) {
  final l10n = context.l10n;
  return [
    MoodiaryNavDestination(
      icon: const Icon(Icons.article_outlined),
      selectedIcon: const Icon(Icons.article),
      label: l10n.homeNavigatorDiary,
    ),
    MoodiaryNavDestination(
      icon: const Icon(UniconsLine.image_v),
      selectedIcon: const Icon(UniconsSolid.image_v),
      label: l10n.homeNavigatorMedia,
    ),
    MoodiaryNavDestination(
      icon: const Icon(Icons.smart_toy_outlined),
      selectedIcon: const Icon(Icons.smart_toy),
      label: l10n.homeNavigatorAssistant,
    ),
  ];
}

class MobileRootShell extends ConsumerStatefulWidget {
  const MobileRootShell({super.key});

  @override
  ConsumerState<MobileRootShell> createState() => _MobileRootShellState();
}

class _MobileRootShellState extends ConsumerState<MobileRootShell> {
  int _index = 0;

  /// 分类抽屉挂在**本层**的 Scaffold 上才盖得住底部导航条；首页在 IndexedStack 里，
  /// 它自己那层 Scaffold 的抽屉只能覆盖内容区。首页拿不到本层的 ScaffoldState
  /// （Scaffold.of 会取到内层那个），所以用 key 显式开。
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  late final _pages = [
    DiaryHomePage(onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer()),
    const MediaPage(),
    const AssistantSessionListPage(),
  ];

  void _newDiary() {
    // 只有站在日记 tab 上才继承当前分类筛选；别的 tab 没有「当前分类」这回事。
    final categoryId = _index == 0
        ? ref.read(homeDiaryFilterProvider).categoryId
        : null;
    openNewDiaryEditor(context, DiaryType.tiptap, categoryId: categoryId);
  }

  @override
  Widget build(BuildContext context) {
    // 多选态下顶栏的汉堡会换成「取消」，边缘手势也必须跟着关 —— 否则入口看着没了、
    // 手一划却还能换分类，而换分类会作废当前的选中集合。
    final selecting = ref.watch(diarySelectionProvider).isNotEmpty;
    final drawerUsable = _index == 0 && !selecting;
    return Scaffold(
      key: _scaffoldKey,
      // 底栏悬浮，内容从它下面穿过去。开这个开关之后 Scaffold 会把底栏的整条带高
      // （胶囊 + 间隙 + 安全区）折进 body 的 MediaQuery.padding.bottom，各 tab 的滚动区
      // 照常读 `MediaQuery.paddingOf(context).bottom` 就能拿到正确留白。
      extendBody: true,
      // 抽屉只服务日记页：其它 tab 上既不给入口，也不让边缘手势划出来。
      drawer: drawerUsable ? const CategoryDrawer() : null,
      drawerEnableOpenDragGesture: drawerUsable,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: MoodiaryNavBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: _navDestinations(context),
        action: MoodiaryNavAction(
          icon: const Icon(Icons.add_rounded),
          tooltip: context.l10n.homePageAddDiaryButton,
          onPressed: _newDiary,
        ),
      ),
    );
  }
}
