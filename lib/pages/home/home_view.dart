import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_adaptive_scaffold/flutter_adaptive_scaffold.dart';
import 'package:moodiary/common/values/diary_type.dart';
import 'package:moodiary/components/base/modal.dart';
import 'package:moodiary/components/desktop_wrapper/background.dart';
import 'package:moodiary/components/home_fab/home_fab_view.dart';
import 'package:moodiary/components/home_nativatorbar/navigatorbar.dart';
import 'package:moodiary/main.dart';
import 'package:moodiary/pages/home/calendar/calendar_view.dart';
import 'package:moodiary/pages/home/diary/diary_view.dart';
import 'package:moodiary/pages/home/media/media_view.dart';
import 'package:moodiary/pages/home/setting/setting_view.dart';
import 'package:refreshed/refreshed.dart';
import 'package:unicons/unicons.dart';

import 'home_logic.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    final HomeLogic logic = Get.put(HomeLogic());
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          AdaptiveLayout(
            transitionDuration: const Duration(milliseconds: 200),
            primaryNavigation: SlotLayout(config: {
              Breakpoints.mediumAndUp: SlotLayout.from(
                key: const ValueKey('navigation medium'),
                builder: (_) {
                  return GestureDetector(
                    onPanStart: (details) {
                      appWindow.startDragging();
                    },
                    child: Obx(() {
                      return Container(
                        padding: const EdgeInsets.all(8.0),
                        color: colorScheme.surfaceContainer,
                        child: AdaptiveScaffold.standardNavigationRail(
                          destinations: [
                            NavigationDestination(
                              icon: const Icon(Icons.article_outlined),
                              label: l10n.homeNavigatorDiary,
                              selectedIcon: const Icon(Icons.article),
                            ),
                            NavigationDestination(
                              icon: const Icon(UniconsLine.calender),
                              label: l10n.homeNavigatorCalendar,
                              selectedIcon: const Icon(UniconsSolid.calender),
                            ),
                            NavigationDestination(
                              icon: const Icon(UniconsLine.image_v),
                              label: l10n.homeNavigatorMedia,
                              selectedIcon: const Icon(UniconsSolid.image_v),
                            ),
                            NavigationDestination(
                              icon: const Icon(UniconsLine.layer_group),
                              label: l10n.homeNavigatorSetting,
                              selectedIcon:
                                  const Icon(UniconsSolid.layer_group),
                            ),
                          ]
                              .map((destination) =>
                                  AdaptiveScaffold.toRailDestination(
                                      destination))
                              .toList(),
                          selectedIndex: logic.navigatorIndex.value,
                          backgroundColor: colorScheme.surfaceContainer,
                          labelType: _isMobile
                              ? NavigationRailLabelType.none
                              : NavigationRailLabelType.all,
                          padding: EdgeInsets.zero,
                          leading: _isMobile ? null : const SizedBox(height: 8),
                          trailing: Expanded(
                            child: DesktopHomeFabComponent(
                              isToTopShow: logic.isToTopShow,
                              toTop: logic.toTop,
                              toMarkdown: () async {
                                await logic.toEditPage(
                                    type: DiaryType.markdown);
                              },
                              toPlainText: () async {
                                await logic.toEditPage(type: DiaryType.text);
                              },
                              toRichText: () async {
                                await logic.toEditPage(
                                    type: DiaryType.richText);
                              },
                            ),
                          ),
                          onDestinationSelected: logic.changeNavigator,
                        ),
                      );
                    }),
                  );
                },
              ),
            }),
            body: SlotLayout(
              config: {
                Breakpoints.standard: SlotLayout.from(
                  key: const ValueKey('body'),
                  builder: (_) {
                    return AdaptiveBackground(
                      child: Obx(() {
                        return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 150),
                            reverseDuration: const Duration(milliseconds: 100),
                            child: switch (logic.navigatorIndex.value) {
                              0 => const DiaryPage(),
                              1 => const CalendarPage(),
                              2 => const MediaPage(),
                              3 => const SettingPage(),
                              _ => throw UnimplementedError(),
                            });
                      }),
                    );
                  },
                )
              },
            ),
          ),
          Modal(
            onTap: logic.closeFab,
            animation: logic.fabAnimation,
          ),
        ],
      ),
      bottomNavigationBar: HomeNavigatorBar(
        animation: logic.barAnimation,
        navigatorIndex: logic.navigatorIndex,
        onTap: logic.changeNavigator,
        modal: Modal(
          onTap: logic.closeFab,
          animation: logic.fabAnimation,
        ),
      ),
      floatingActionButton: HomeFabComponent(
        animation: logic.fabAnimation,
        shouldShow: logic.shouldShow,
        isToTopShow: logic.isToTopShow,
        isExpanded: logic.isFabExpanded,
        toTop: logic.toTop,
        toMarkdown: () async {
          await logic.toEditPage(type: DiaryType.markdown);
        },
        toPlainText: () async {
          await logic.toEditPage(type: DiaryType.text);
        },
        toRichText: () async {
          await logic.toEditPage(type: DiaryType.richText);
        },
        closeFab: logic.closeFab,
        openFab: logic.openFab,
      ),
    );
  }
}
