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
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:mui/mui.dart';

import 'mood_upgrade_notice.dart';

enum _ShellTab { diary, assistant, me }

MNavDestination _navDestination(BuildContext context, _ShellTab tab) {
  final l10n = context.l10n;
  return switch (tab) {
    .diary => MNavDestination(
      icon: const Icon(LucideIcons.bookText),
      label: l10n.app.homeNavigatorDiary,
    ),
    .assistant => MNavDestination(
      icon: const Icon(LucideIcons.astroid),
      label: l10n.app.homeNavigatorAssistant,
    ),
    .me => MNavDestination(
      icon: const Icon(LucideIcons.circleUser),
      label: l10n.app.homeNavigatorMe,
    ),
  };
}

class MobileRootShell extends ConsumerStatefulWidget {
  const MobileRootShell({super.key});

  @override
  ConsumerState<MobileRootShell> createState() => _MobileRootShellState();
}

class _MobileRootShellState extends ConsumerState<MobileRootShell> {
  _ShellTab _tab = .diary;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showPendingMoodNotice(context);
    });
  }

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
    return ValueListenableBuilder<bool>(
      valueListenable: MoodiaryKVs.assistantEnabled.getNotifier(),
      builder: (context, enabled, _) {
        final tabs = enabled
            ? _ShellTab.values
            : const [_ShellTab.diary, _ShellTab.me];
        if (!enabled && _tab == .assistant) _tab = .diary;
        final drawerUsable = _tab == .diary && !selecting;
        return Scaffold(
          key: _scaffoldKey,
          extendBody: true,
          drawer: drawerUsable ? const CategoryDrawer() : null,
          drawerEnableOpenDragGesture: drawerUsable,
          body: MLazyIndexedStack(index: _tab.index, children: _pages),
          bottomNavigationBar: MNavBar(
            selectedIndex: tabs.indexOf(_tab),
            onDestinationSelected: (index) =>
                setState(() => _tab = tabs[index]),
            destinations: [
              for (final tab in tabs) _navDestination(context, tab),
            ],
            action: _navAction(context),
          ),
        );
      },
    );
  }
}
