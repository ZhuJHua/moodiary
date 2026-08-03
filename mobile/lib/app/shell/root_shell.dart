import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_assistant/moodiary_assistant.dart'
    show AssistantConversationRoute, AssistantSessionListPage;
import 'package:moodiary/app/home/diary_home_page.dart' show DiaryHomePage;
import 'package:moodiary_diary/moodiary_diary.dart'
    show CategoryDrawer, diarySelectionProvider, homeDiaryFilterProvider;
import 'package:moodiary_editor/moodiary_editor.dart' show openNewDiaryEditor;
import 'package:moodiary_media/moodiary_media.dart';
import 'package:moodiary_models/moodiary_models.dart' show DiaryType;
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_ui/moodiary_ui.dart'
    show LucideIcons, MoodiaryNavAction, MoodiaryNavBar, MoodiaryNavDestination;

/// 三个 tab —— 设置不在这儿，入口在分类抽屉底部（胶囊只装得下三个，加上右边那颗
/// 动作按钮正好一行）。枚举顺序即胶囊里的顺序，也是 `_pages` 的顺序。
enum _ShellTab { diary, media, assistant }

List<MoodiaryNavDestination> _navDestinations(BuildContext context) {
  final l10n = context.l10n;
  return [
    MoodiaryNavDestination(
      icon: const Icon(LucideIcons.bookText),
      label: l10n.homeNavigatorDiary,
    ),
    MoodiaryNavDestination(
      icon: const Icon(LucideIcons.image),
      label: l10n.homeNavigatorMedia,
    ),
    MoodiaryNavDestination(
      icon: const Icon(LucideIcons.astroid),
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
  _ShellTab _tab = _ShellTab.diary;

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
    final categoryId = _tab == _ShellTab.diary
        ? ref.read(homeDiaryFilterProvider).categoryId
        : null;
    openNewDiaryEditor(context, DiaryType.tiptap, categoryId: categoryId);
  }

  /// 右边那颗按钮跟着 tab 换功能。媒体页没有自己的「创建」——它是逛出来的，所以
  /// 和日记页共用写日记；只有助手页换成开新对话（那颗 FAB 因此撤掉了）。
  MoodiaryNavAction _navAction(BuildContext context) {
    final l10n = context.l10n;
    return switch (_tab) {
      _ShellTab.assistant => MoodiaryNavAction(
        icon: const Icon(LucideIcons.messageCirclePlus),
        tooltip: l10n.assistantNewChat,
        onPressed: () => const AssistantConversationRoute().push(context),
      ),
      _ShellTab.diary || _ShellTab.media => MoodiaryNavAction(
        icon: const Icon(LucideIcons.pencilLine),
        tooltip: l10n.homePageAddDiaryButton,
        onPressed: _newDiary,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    // 多选态下顶栏的汉堡会换成「取消」，边缘手势也必须跟着关 —— 否则入口看着没了、
    // 手一划却还能换分类，而换分类会作废当前的选中集合。
    final selecting = ref.watch(diarySelectionProvider).isNotEmpty;
    final drawerUsable = _tab == _ShellTab.diary && !selecting;
    return Scaffold(
      key: _scaffoldKey,
      // 底栏悬浮，内容从它下面穿过去。开这个开关之后 Scaffold 会把底栏的整条带高
      // （胶囊 + 间隙 + 安全区）折进 body 的 MediaQuery.padding.bottom，各 tab 的滚动区
      // 照常读 `MediaQuery.paddingOf(context).bottom` 就能拿到正确留白。
      extendBody: true,
      // 抽屉只服务日记页：其它 tab 上既不给入口，也不让边缘手势划出来。
      drawer: drawerUsable ? const CategoryDrawer() : null,
      drawerEnableOpenDragGesture: drawerUsable,
      body: IndexedStack(index: _tab.index, children: _pages),
      bottomNavigationBar: MoodiaryNavBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (i) =>
            setState(() => _tab = _ShellTab.values[i]),
        destinations: _navDestinations(context),
        action: _navAction(context),
      ),
    );
  }
}
