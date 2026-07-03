import 'package:flutter/material.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:unicons/unicons.dart';
import 'package:moodiary_assistant/moodiary_assistant.dart'
    show AssistantSessionListPage;
import 'package:moodiary/feature/diary/presentation/diary_page.dart'
    show DiaryListPageMobile;
import 'package:moodiary_media/moodiary_media.dart';
import 'package:moodiary/feature/setting/presentation/setting_page.dart'
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

class MobileRootShell extends StatefulWidget {
  const MobileRootShell({super.key});

  @override
  State<MobileRootShell> createState() => _MobileRootShellState();
}

class _MobileRootShellState extends State<MobileRootShell> {
  int _index = 0;

  static const _pages = [
    DiaryListPageMobile(),
    MediaPage(),
    AssistantSessionListPage(),
    SettingListPageMobile(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: _navDestinations(context),
      ),
    );
  }
}
