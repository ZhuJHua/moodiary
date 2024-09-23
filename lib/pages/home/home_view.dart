import 'dart:io';
import 'dart:math';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/border.dart';
import 'package:mood_diary/components/keepalive/keepalive.dart';
import 'package:mood_diary/pages/home/assistant/assistant_view.dart';
import 'package:mood_diary/pages/home/calendar/calendar_view.dart';
import 'package:mood_diary/pages/home/diary/diary_view.dart';
import 'package:mood_diary/pages/home/setting/setting_view.dart';

import 'home_logic.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<HomeLogic>();
    final state = Bind.find<HomeLogic>().state;
    final colorScheme = Theme.of(context).colorScheme;
    final i18n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);

    Widget buildModal() {
      return AnimatedBuilder(
          animation: logic.fabAnimation,
          builder: (context, child) {
            return state.isFabExpanded.value
                ? ModalBarrier(
                    color: colorScheme.surface.withAlpha((255 * 0.6 * logic.fabAnimation.value).toInt()),
                    onDismiss: () async {
                      await logic.closeFab();
                    },
                  )
                : const SizedBox.shrink();
          });
    }

    Widget buildToTopButton() {
      return logic.diaryLogic.state.isToTopShow.value && state.isFabExpanded.value == false
          ? Transform(
              transform: Matrix4.identity()..translate(.0, -(56.0 + 8.0)),
              alignment: FractionalOffset.center,
              child: InkWell(
                onTap: () async {
                  await logic.diaryLogic.toTop();
                },
                child: Container(
                  decoration: ShapeDecoration(
                    shape: const RoundedRectangleBorder(borderRadius: AppBorderRadius.largeBorderRadius),
                    color: colorScheme.tertiaryContainer,
                  ),
                  width: 56.0,
                  height: 56.0,
                  child: const Icon(Icons.arrow_upward),
                ),
              ),
            )
          : const SizedBox.shrink();
    }

    Widget buildAddDiaryButton() {
      return AnimatedBuilder(
        animation: logic.fabAnimation,
        child: InkWell(
          onTap: () async {
            await logic.toEditPage();
          },
          child: Container(
            decoration: ShapeDecoration(
              shape: const RoundedRectangleBorder(borderRadius: AppBorderRadius.largeBorderRadius),
              color: colorScheme.primaryContainer,
            ),
            height: 56.0,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 16.0,
              children: [
                Icon(
                  Icons.edit,
                  color: colorScheme.onPrimaryContainer,
                ),
                Text(
                  i18n.homePageAddDiaryButton,
                  style: TextStyle(color: colorScheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ),
        builder: (context, child) {
          return Transform(
            transform: Matrix4.identity()
              ..scale(pow(logic.fabAnimation.value, 2).toDouble(), logic.fabAnimation.value)
              ..translate(.0, -((56.0 + 8.0)) * logic.fabAnimation.value),
            alignment: FractionalOffset.centerRight,
            child: child,
          );
        },
      );
    }

    Widget buildFabButton() {
      return AnimatedBuilder(
          animation: logic.fabAnimation,
          child: const Icon(Icons.add),
          builder: (context, child) {
            return FloatingActionButton(
              onPressed: () async {
                state.isFabExpanded.value ? await logic.closeFab() : await logic.openFab();
              },
              backgroundColor:
                  Color.lerp(colorScheme.primaryContainer, colorScheme.tertiaryContainer, logic.fabAnimation.value),
              child: Transform.rotate(
                angle: 3 * pi / 4 * logic.fabAnimation.value,
                child: child,
              ),
            );
          });
    }

    Widget? buildFab() {
      if (state.navigatorIndex.value == 0) {
        return Obx(() {
          return SizedBox(
            height: state.isFabExpanded.value || logic.diaryLogic.state.isToTopShow.value ? 56 + (56 + 8) : 56,
            width: state.isFabExpanded.value ? 156 : 56,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Obx(() {
                  return buildToTopButton();
                }),
                buildAddDiaryButton(),
                buildFabButton(),
              ],
            ),
          );
        });
      } else {
        return null;
      }
    }

    Widget buildNavigatorBar() {
      return size.aspectRatio < 1.0
          ? AnimatedBuilder(
              animation: logic.barAnimation,
              builder: (context, child) {
                return SizedBox(
                  height: state.navigatorBarHeight * logic.barAnimation.value,
                  child: child,
                );
              },
              child: Stack(
                children: [
                  Obx(() {
                    return NavigationBar(
                      destinations: [
                        NavigationDestination(
                          icon: const Icon(Icons.article_outlined),
                          label: i18n.homeNavigatorDiary,
                          selectedIcon: const Icon(Icons.article),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: i18n.homeNavigatorCalendar,
                          selectedIcon: const Icon(Icons.calendar_today),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.chat_outlined),
                          label: i18n.homeNavigatorAssistant,
                          selectedIcon: const Icon(Icons.chat),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.settings_outlined),
                          label: i18n.homeNavigatorSetting,
                          selectedIcon: const Icon(Icons.settings),
                        ),
                      ],
                      selectedIndex: state.navigatorIndex.value,
                      height: state.navigatorBarHeight,
                      backgroundColor: colorScheme.surface,
                      onDestinationSelected: (index) {
                        logic.changeNavigator(index);
                      },
                      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                    );
                  }),
                  buildModal()
                ],
              ),
            )
          : const SizedBox.shrink();
    }

    Widget buildNavigatorRail() {
      return size.aspectRatio >= 1.0
          ? SizedBox(
              width: 80.0,
              child: Stack(
                children: [
                  Obx(() {
                    return NavigationRail(
                      backgroundColor: Colors.transparent,
                      destinations: [
                        NavigationRailDestination(
                          icon: const Icon(Icons.article_outlined),
                          label: Text(i18n.homeNavigatorDiary),
                          selectedIcon: const Icon(Icons.article),
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text(i18n.homeNavigatorCalendar),
                          selectedIcon: const Icon(Icons.calendar_today),
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.chat_outlined),
                          label: Text(i18n.homeNavigatorAssistant),
                          selectedIcon: const Icon(Icons.chat),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.settings_outlined),
                          label: Text(i18n.homeNavigatorSetting),
                          selectedIcon: const Icon(Icons.settings),
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                        )
                      ],
                      labelType: NavigationRailLabelType.selected,
                      selectedIndex: state.navigatorIndex.value,
                      onDestinationSelected: (index) {
                        logic.changeNavigator(index);
                      },
                    );
                  }),
                  buildModal()
                ],
              ),
            )
          : const SizedBox.shrink();
    }

    return GetBuilder<HomeLogic>(
      init: logic,
      assignId: true,
      builder: (logic) {
        return Row(
          children: [
            //侧边导航栏
            buildNavigatorRail(),
            Expanded(
              child: Scaffold(
                appBar: Platform.isWindows
                    ? PreferredSize(
                        preferredSize: Size.fromHeight(appWindow.titleBarHeight),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            MinimizeWindowButton(
                              colors: WindowButtonColors(
                                iconNormal: colorScheme.secondary,
                                mouseDown: colorScheme.secondaryContainer,
                                normal: colorScheme.surface,
                                iconMouseDown: colorScheme.secondary,
                                mouseOver: colorScheme.secondaryContainer,
                                iconMouseOver: colorScheme.onSecondaryContainer,
                              ),
                            ),
                            MaximizeWindowButton(
                              colors: WindowButtonColors(
                                iconNormal: colorScheme.secondary,
                                mouseDown: colorScheme.secondaryContainer,
                                normal: colorScheme.surface,
                                iconMouseDown: colorScheme.secondary,
                                mouseOver: colorScheme.secondaryContainer,
                                iconMouseOver: colorScheme.onSecondaryContainer,
                              ),
                            ),
                            CloseWindowButton(
                              colors: WindowButtonColors(
                                iconNormal: colorScheme.secondary,
                                mouseDown: colorScheme.secondaryContainer,
                                normal: colorScheme.surface,
                                iconMouseDown: colorScheme.secondary,
                                mouseOver: colorScheme.errorContainer,
                                iconMouseOver: colorScheme.onErrorContainer,
                              ),
                            ),
                          ],
                        ))
                    : null,
                body: Stack(
                  children: [
                    //主布局
                    PageView(
                      controller: logic.pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: const [
                        KeepAliveWrapper(child: DiaryPage()),
                        CalendarPage(),
                        AssistantPage(),
                        SettingPage(),
                      ],
                    ),
                    //遮罩
                    buildModal()
                  ],
                ),
                floatingActionButton: buildFab(),
                bottomNavigationBar: buildNavigatorBar(),
              ),
            ),
          ],
        );
      },
    );
  }
}
