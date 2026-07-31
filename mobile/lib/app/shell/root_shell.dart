import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:unicons/unicons.dart';
import 'package:moodiary_assistant/moodiary_assistant.dart'
    show AssistantSessionListPage;
import 'package:moodiary/app/home/diary_home_page.dart' show DiaryHomePage;
import 'package:moodiary_diary/moodiary_diary.dart'
    show CategoryDrawer, diarySelectionProvider;
import 'package:moodiary_media/moodiary_media.dart';
import 'package:moodiary/app/settings/presentation/setting_page.dart'
    show SettingListPageMobile;

List<NavigationDestination> _navDestinations(BuildContext context) {
  final l10n = context.l10n;
  return [
    NavigationDestination(
      icon: const Icon(Icons.article_outlined),
      selectedIcon: const Icon(Icons.article),
      label: l10n.homeNavigatorDiary,
    ),
    NavigationDestination(
      icon: const Icon(UniconsLine.image_v),
      selectedIcon: const Icon(UniconsSolid.image_v),
      label: l10n.homeNavigatorMedia,
    ),
    NavigationDestination(
      icon: const Icon(Icons.smart_toy_outlined),
      selectedIcon: const Icon(Icons.smart_toy),
      label: l10n.homeNavigatorAssistant,
    ),
    NavigationDestination(
      icon: const Icon(UniconsLine.layer_group),
      selectedIcon: const Icon(UniconsSolid.layer_group),
      label: l10n.homeNavigatorSetting,
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
    const SettingListPageMobile(),
  ];

  @override
  Widget build(BuildContext context) {
    // 多选态下顶栏的汉堡会换成「取消」，边缘手势也必须跟着关 —— 否则入口看着没了、
    // 手一划却还能换分类，而换分类会作废当前的选中集合。
    final selecting = ref.watch(diarySelectionProvider).isNotEmpty;
    final drawerUsable = _index == 0 && !selecting;
    return Scaffold(
      key: _scaffoldKey,
      // 抽屉只服务日记页：其它 tab 上既不给入口，也不让边缘手势划出来。
      drawer: drawerUsable ? const CategoryDrawer() : null,
      drawerEnableOpenDragGesture: drawerUsable,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: _navDestinations(context),
      ),
    );
  }
}
