import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_adaptive_scaffold/flutter_adaptive_scaffold.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/border.dart';
import 'package:mood_diary/pages/home/calendar/calendar_view.dart';
import 'package:mood_diary/pages/home/diary/diary_view.dart';
import 'package:mood_diary/pages/home/media/media_view.dart';
import 'package:mood_diary/pages/home/setting/setting_view.dart';
import 'package:unicons/unicons.dart';

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
            return state.isFabExpanded
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
      return state.isToTopShow && state.isFabExpanded == false
          ? Transform(
              transform: Matrix4.identity()..translate(.0, -(56.0 + 8.0)),
              alignment: FractionalOffset.center,
              child: GestureDetector(
                onTap: () async {
                  await logic.diaryLogic.toTop();
                },
                child: Container(
                  decoration: ShapeDecoration(
                      shape: const RoundedRectangleBorder(borderRadius: AppBorderRadius.largeBorderRadius),
                      color: colorScheme.tertiaryContainer,
                      shadows: [
                        BoxShadow(
                            color: colorScheme.shadow.withAlpha((255 * 0.1).toInt()),
                            offset: const Offset(0, 2),
                            blurRadius: 2,
                            spreadRadius: 2)
                      ]),
                  width: 56.0,
                  height: 56.0,
                  child: Center(
                      child: FaIcon(
                    FontAwesomeIcons.arrowUp,
                    color: colorScheme.onTertiaryContainer,
                  )),
                ),
              ),
            )
          : const SizedBox.shrink();
    }

    Widget buildAddDiaryButton() {
      return AnimatedBuilder(
        animation: logic.fabAnimation,
        child: GestureDetector(
          onTap: () async {
            await logic.toEditPage();
          },
          child: Container(
            decoration: ShapeDecoration(
                shape: const RoundedRectangleBorder(borderRadius: AppBorderRadius.largeBorderRadius),
                color: colorScheme.primaryContainer,
                shadows: [
                  BoxShadow(
                      color: colorScheme.shadow.withAlpha((255 * 0.1).toInt()),
                      offset: const Offset(0, 2),
                      blurRadius: 2,
                      spreadRadius: 2)
                ]),
            height: 56.0,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 16.0,
              children: [
                FaIcon(
                  FontAwesomeIcons.feather,
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

    Widget buildToAiButton() {
      return AnimatedBuilder(
        animation: logic.fabAnimation,
        child: GestureDetector(
          onTap: () async {
            await logic.toAi();
          },
          child: Container(
            decoration: ShapeDecoration(
                shape: const RoundedRectangleBorder(borderRadius: AppBorderRadius.largeBorderRadius),
                color: colorScheme.primaryContainer,
                shadows: [
                  BoxShadow(
                      color: colorScheme.shadow.withAlpha((255 * 0.1).toInt()),
                      offset: const Offset(0, 2),
                      blurRadius: 2,
                      spreadRadius: 2)
                ]),
            height: 56.0,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 16.0,
              children: [
                FaIcon(
                  FontAwesomeIcons.solidCommentDots,
                  color: colorScheme.onPrimaryContainer,
                ),
                Text(
                  '智能助手',
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
              ..translate(.0, -((56.0 + 8.0) * 3) * logic.fabAnimation.value),
            alignment: FractionalOffset.centerRight,
            child: child,
          );
        },
      );
    }

    Widget buildToMapButton() {
      return AnimatedBuilder(
        animation: logic.fabAnimation,
        child: GestureDetector(
          onTap: () async {
            await logic.toMap();
          },
          child: Container(
            decoration: ShapeDecoration(
                shape: const RoundedRectangleBorder(borderRadius: AppBorderRadius.largeBorderRadius),
                color: colorScheme.primaryContainer,
                shadows: [
                  BoxShadow(
                      color: colorScheme.shadow.withAlpha((255 * 0.1).toInt()),
                      offset: const Offset(0, 2),
                      blurRadius: 2,
                      spreadRadius: 2)
                ]),
            height: 56.0,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 16.0,
              children: [
                FaIcon(
                  FontAwesomeIcons.solidMap,
                  color: colorScheme.onPrimaryContainer,
                ),
                Text(
                  '查看足迹',
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
              ..translate(.0, -((56.0 + 8.0) * 2) * logic.fabAnimation.value),
            alignment: FractionalOffset.centerRight,
            child: child,
          );
        },
      );
    }

    Widget buildFabButton() {
      return AnimatedBuilder(
          animation: logic.fabAnimation,
          builder: (context, child) {
            return GestureDetector(
              onTap: () async {
                state.isFabExpanded ? await logic.closeFab() : await logic.openFab();
              },
              child: Container(
                width: 56.0,
                height: 56.0,
                decoration: ShapeDecoration(
                    shape: const RoundedRectangleBorder(borderRadius: AppBorderRadius.largeBorderRadius),
                    color: Color.lerp(
                        colorScheme.primaryContainer, colorScheme.tertiaryContainer, logic.fabAnimation.value),
                    shadows: [
                      BoxShadow(
                          color: colorScheme.shadow.withAlpha((255 * 0.1).toInt()),
                          offset: const Offset(0, 2),
                          blurRadius: 2,
                          spreadRadius: 2)
                    ]),
                child: Transform.rotate(
                    angle: 3 * pi / 4 * logic.fabAnimation.value,
                    child: Icon(
                      FontAwesomeIcons.plus,
                      color: Color.lerp(
                          colorScheme.onPrimaryContainer, colorScheme.onTertiaryContainer, logic.fabAnimation.value),
                    )),
              ),
            );
          });
    }

    Widget buildFab() {
      return state.navigatorIndex == 0
          ? SizedBox(
              height: state.isFabExpanded || state.isToTopShow ? 56 + (56 + 8) * 3 : 56,
              width: state.isFabExpanded ? 156 : 56,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  buildToTopButton(),
                  buildToAiButton(),
                  buildToMapButton(),
                  buildAddDiaryButton(),
                  buildFabButton(),
                ],
              ),
            )
          : const SizedBox.shrink();
    }

    // 导航栏
    final List<NavigationDestination> destinations = [
      NavigationDestination(
        icon: const Icon(Icons.article_outlined),
        label: i18n.homeNavigatorDiary,
        selectedIcon: const Icon(Icons.article),
      ),
      NavigationDestination(
        icon: const Icon(UniconsLine.calender),
        label: i18n.homeNavigatorCalendar,
        selectedIcon: const Icon(UniconsSolid.calender),
      ),
      NavigationDestination(
        icon: const Icon(UniconsLine.image_v),
        label: i18n.homeNavigatorMedia,
        selectedIcon: const Icon(UniconsSolid.image_v),
      ),
      NavigationDestination(
        icon: const Icon(UniconsLine.layer_group),
        label: i18n.homeNavigatorSetting,
        selectedIcon: const Icon(UniconsSolid.layer_group),
      ),
    ];
    // Widget buildWindowsBar() {
    //   return Container(
    //     color: Platform.isMacOS ? colorScheme.surface : colorScheme.surfaceContainer,
    //     child: Row(
    //       mainAxisAlignment: Platform.isMacOS ? MainAxisAlignment.end : MainAxisAlignment.spaceBetween,
    //       children: [
    //         Padding(
    //           padding: const EdgeInsets.only(left: 8.0),
    //           child: Row(
    //             spacing: 8.0,
    //             children: [
    //               if (!Platform.isMacOS) ...[
    //                 ClipRRect(
    //                   borderRadius: const BorderRadius.all(Radius.circular(4.0)),
    //                   child: Image.asset(
    //                     'assets/icon/icon.png',
    //                     height: 16.0,
    //                     width: 16.0,
    //                   ),
    //                 )
    //               ],
    //               Text(state.hitokoto),
    //             ],
    //           ),
    //         ),
    //         if (!Platform.isMacOS) ...[
    //           Row(
    //             children: [
    //               MinimizeWindowButton(
    //                 colors: WindowButtonColors(
    //                   iconNormal: colorScheme.secondary,
    //                   mouseDown: colorScheme.secondaryContainer,
    //                   normal: colorScheme.surfaceContainer,
    //                   iconMouseDown: colorScheme.secondary,
    //                   mouseOver: colorScheme.secondaryContainer,
    //                   iconMouseOver: colorScheme.onSecondaryContainer,
    //                 ),
    //               ),
    //               MaximizeWindowButton(
    //                 colors: WindowButtonColors(
    //                   iconNormal: colorScheme.secondary,
    //                   mouseDown: colorScheme.secondaryContainer,
    //                   normal: colorScheme.surfaceContainer,
    //                   iconMouseDown: colorScheme.secondary,
    //                   mouseOver: colorScheme.secondaryContainer,
    //                   iconMouseOver: colorScheme.onSecondaryContainer,
    //                 ),
    //               ),
    //               CloseWindowButton(
    //                 colors: WindowButtonColors(
    //                   iconNormal: colorScheme.secondary,
    //                   mouseDown: colorScheme.secondaryContainer,
    //                   normal: colorScheme.surfaceContainer,
    //                   iconMouseDown: colorScheme.secondary,
    //                   mouseOver: colorScheme.errorContainer,
    //                   iconMouseOver: colorScheme.onErrorContainer,
    //                 ),
    //               ),
    //             ],
    //           )
    //         ]
    //       ],
    //     ),
    //   );
    // }

    Widget buildNavigatorBar() {
      return size.width < 600
          ? AnimatedBuilder(
              animation: logic.barAnimation,
              builder: (context, child) {
                return SizedBox(
                  height: state.navigatorBarHeight * logic.barAnimation.value,
                  child: child,
                );
              },
              child: Container(
                height: state.navigatorBarHeight * logic.barAnimation.value,
                decoration: BoxDecoration(border: Border(top: BorderSide(color: colorScheme.outline, width: 0.2))),
                child: Stack(
                  children: [
                    NavigationBar(
                      destinations: destinations,
                      selectedIndex: state.navigatorIndex,
                      height: state.navigatorBarHeight,
                      onDestinationSelected: (index) {
                        logic.changeNavigator(index);
                      },
                      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                    ),
                    buildModal()
                  ],
                ),
              ),
            )
          : const SizedBox.shrink();
    }

    Widget buildLayout() {
      return AdaptiveLayout(
        transitionDuration: const Duration(milliseconds: 200),
        primaryNavigation: SlotLayout(config: {
          Breakpoints.medium: SlotLayout.from(
            key: const ValueKey('primary navigation medium'),
            builder: (_) {
              return AdaptiveScaffold.standardNavigationRail(
                destinations:
                    destinations.map((destination) => AdaptiveScaffold.toRailDestination(destination)).toList(),
                selectedIndex: state.navigatorIndex,
                onDestinationSelected: (index) {
                  logic.changeNavigator(index);
                },
              );
            },
          ),
          Breakpoints.mediumLargeAndUp: SlotLayout.from(
            key: const ValueKey('primary navigation medium large'),
            builder: (_) => AdaptiveScaffold.standardNavigationRail(
              destinations: destinations.map((destination) => AdaptiveScaffold.toRailDestination(destination)).toList(),
              extended: true,
              selectedIndex: state.navigatorIndex,
              onDestinationSelected: (index) {
                logic.changeNavigator(index);
              },
            ),
          ),
        }),
        body: SlotLayout(config: {
          Breakpoints.standard: SlotLayout.from(
              key: const ValueKey('body'),
              builder: (_) => PageView(
                    controller: logic.pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: const [
                      DiaryPage(),
                      CalendarPage(),
                      MediaPage(),
                      SettingPage(),
                    ],
                  ))
        }),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          GetBuilder<HomeLogic>(
              id: 'Layout',
              builder: (_) {
                return buildLayout();
              }),
          buildModal()
        ],
      ),
      bottomNavigationBar: GetBuilder<HomeLogic>(
        id: 'NavigatorBar',
        builder: (_) {
          return buildNavigatorBar();
        },
      ),
      floatingActionButton: GetBuilder<HomeLogic>(
        id: 'Fab',
        builder: (_) {
          return buildFab();
        },
      ),
    );
  }
}
