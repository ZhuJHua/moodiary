import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_assistant/moodiary_assistant.dart'
    show AssistantSessionListPage;
import 'package:moodiary_diary/moodiary_diary.dart'
    show CategoryDrawer, diarySelectionProvider, homeDiaryFilterProvider;
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_mobile/app/home/diary_home_page.dart'
    show DiaryHomePage;
import 'package:moodiary_mobile/app/me/me_page.dart' show MePage;
import 'package:moodiary_router/moodiary_router.dart';
import 'package:mui/mui.dart';

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

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  late final List<Widget> _pages = [
    DiaryHomePage(onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer()),
    const AssistantSessionListPage(),
    const MePage(),
  ];

  Future<void> _newDiary() async {
    final categoryId = _tab == .diary
        ? ref.read(homeDiaryFilterProvider).categoryId
        : null;
    await NewDiaryRoute(categoryId: categoryId).push(context);
  }

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
    final selecting = ref.watch(diarySelectionProvider).isNotEmpty;
    final drawerUsable = _tab == .diary && !selecting;
    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      drawer: drawerUsable ? const CategoryDrawer() : null,
      drawerEnableOpenDragGesture: drawerUsable,
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
