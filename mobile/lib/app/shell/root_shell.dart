import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_mobile/app/home/diary_home_page.dart' show DiaryHomePage;
import 'package:moodiary_mobile/app/me/me_page.dart' show MePage;
import 'package:moodiary_assistant/moodiary_assistant.dart'
    show AssistantConversationRoute, AssistantSessionListPage;
import 'package:moodiary_diary/moodiary_diary.dart'
    show
        CategoryDrawer,
        diarySelectionProvider,
        homeDiaryFilterProvider,
        openNewDiaryEditor;
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:mui/mui.dart';

/// 三个 tab —— 媒体库不在这儿了，它是「同一批日记的另一个投影」，和地图、知识图谱
/// 一起收进了「我的 · 回顾」。枚举顺序即胶囊里的顺序，也是 `_pageFor` 的顺序。
enum _ShellTab { diary, assistant, me }

List<MNavDestination> _navDestinations(BuildContext context) {
  final l10n = context.l10n;
  return [
    MNavDestination(
      icon: const Icon(LucideIcons.bookText),
      label: l10n.app.homeNavigatorDiary,
    ),
    MNavDestination(
      icon: const Icon(LucideIcons.astroid),
      label: l10n.app.homeNavigatorAssistant,
    ),
    MNavDestination(
      icon: const Icon(LucideIcons.circleUser),
      label: l10n.app.homeNavigatorMe,
    ),
  ];
}

class MobileRootShell extends ConsumerStatefulWidget {
  const MobileRootShell({super.key});

  @override
  ConsumerState<MobileRootShell> createState() => _MobileRootShellState();
}

class _MobileRootShellState extends ConsumerState<MobileRootShell> {
  _ShellTab _tab = .diary;

  /// 分类抽屉挂在**本层**的 Scaffold 上才盖得住底部导航条；首页在 stack 里，
  /// 它自己那层 Scaffold 的抽屉只能覆盖内容区。首页拿不到本层的 ScaffoldState
  /// （Scaffold.of 会取到内层那个），所以用 key 显式开。
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// 只建一次。三个 widget 实例逐帧复用，壳因为多选态重建时
  /// `Element.updateChild` 会因为 `identical` 直接短路，三个 tab 都不跟着重建。
  /// 顺序必须与 [_ShellTab] 一致 —— stack 是按位置寻址的。
  late final List<Widget> _pages = [
    DiaryHomePage(onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer()),
    const AssistantSessionListPage(),
    const MePage(),
  ];

  void _newDiary() {
    // 只有站在日记 tab 上才继承当前分类筛选；别的 tab 没有「当前分类」这回事。
    final categoryId = _tab == .diary
        ? ref.read(homeDiaryFilterProvider).categoryId
        : null;
    openNewDiaryEditor(context, .tiptap, categoryId: categoryId);
  }

  /// 右边那颗按钮 = 当前 tab 的主动作，三个 tab 各一个：写日记 / 新对话 / 设置。
  ///
  /// 它**永远存在** —— 胶囊是 `Expanded`，动作按钮一旦为 null 胶囊就会变宽，
  /// 选中药丸的位置整体跳一下。「我的」页本来也没有「创建」这回事，那一格正好给设置，
  /// 于是设置在三个 tab 里有了一个位置固定、一屏可达的入口。
  MNavAction _navAction(BuildContext context) {
    final l10n = context.l10n;
    return switch (_tab) {
      .diary => MNavAction(
        icon: const Icon(LucideIcons.pencilLine),
        tooltip: l10n.app.homePageAddDiaryButton,
        onPressed: _newDiary,
      ),
      .assistant => MNavAction(
        icon: const Icon(LucideIcons.messageCirclePlus),
        tooltip: l10n.assistant.newChat,
        onPressed: () => const AssistantConversationRoute().push(context),
      ),
      .me => MNavAction(
        icon: const Icon(LucideIcons.settings),
        tooltip: l10n.app.settingsTitle,
        onPressed: () => const SettingRoute().push(context),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    // 多选态下顶栏的汉堡会换成「取消」，边缘手势也必须跟着关 —— 否则入口看着没了、
    // 手一划却还能换分类，而换分类会作废当前的选中集合。
    final selecting = ref.watch(diarySelectionProvider).isNotEmpty;
    final drawerUsable = _tab == .diary && !selecting;
    return Scaffold(
      key: _scaffoldKey,
      // 底栏悬浮，内容从它下面穿过去。开这个开关之后 Scaffold 会把底栏的整条带高
      // （胶囊 + 间隙 + 安全区）折进 body 的 MediaQuery.padding.bottom，各 tab 的滚动区
      // 照常读 `MediaQuery.paddingOf(context).bottom` 就能拿到正确留白。
      extendBody: true,
      // 抽屉只服务日记页：其它 tab 上既不给入口，也不让边缘手势划出来。
      drawer: drawerUsable ? const CategoryDrawer() : null,
      drawerEnableOpenDragGesture: drawerUsable,
      // 懒建：裸 IndexedStack 会把三个 tab 都 build 出来，冷启动时「我的」页就已经去
      // 扫库了。没进过的那格先占位，切过去才建；建过之后一直留着，State 不丢。
      body: MLazyIndexedStack(index: _tab.index, children: _pages),
      bottomNavigationBar: MNavBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (i) =>
            setState(() => _tab = _ShellTab.values[i]),
        destinations: _navDestinations(context),
        action: _navAction(context),
      ),
    );
  }
}
