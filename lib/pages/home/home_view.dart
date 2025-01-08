import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_adaptive_scaffold/flutter_adaptive_scaffold.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mood_diary/common/values/border.dart';
import 'package:mood_diary/common/values/diary_type.dart';
import 'package:mood_diary/pages/home/calendar/calendar_view.dart';
import 'package:mood_diary/pages/home/diary/diary_view.dart';
import 'package:mood_diary/pages/home/media/media_view.dart';
import 'package:mood_diary/pages/home/setting/setting_view.dart';
import 'package:refreshed/refreshed.dart';
import 'package:unicons/unicons.dart';

import '../../main.dart';
import 'home_logic.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<HomeLogic>();
    final state = Bind.find<HomeLogic>().state;
    final colorScheme = Theme.of(context).colorScheme;

    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final textStyle = Theme.of(context).textTheme;

    Widget buildModal() {
      return AnimatedBuilder(
          animation: logic.fabAnimation,
          builder: (context, child) {
            return state.isFabExpanded
                ? ModalBarrier(
                    color: colorScheme.surfaceContainer.withAlpha(
                        (255 * 0.6 * logic.fabAnimation.value).toInt()),
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
                      shape: const RoundedRectangleBorder(
                          borderRadius: AppBorderRadius.largeBorderRadius),
                      color: colorScheme.tertiaryContainer,
                      shadows: [
                        BoxShadow(
                            color: colorScheme.shadow
                                .withAlpha((255 * 0.1).toInt()),
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

    Widget buildAnimatedActionButton({
      required String label,
      required Function() onTap,
      required IconData iconData,
      required int index,
    }) {
      const double mainButtonHeight = 56.0;
      const double mainButtonSpacing = 8.0;
      const double secondaryButtonHeight = 46.0;

      double calculateVerticalTranslation(int index, double animationValue) {
        const double baseOffset = mainButtonHeight + mainButtonSpacing;
        return index == 1
            ? baseOffset * index * animationValue
            : (baseOffset +
                    (secondaryButtonHeight + mainButtonSpacing) * (index - 1)) *
                animationValue;
      }

      return Visibility(
        visible: state.isFabExpanded,
        child: AnimatedBuilder(
          animation: logic.fabAnimation,
          builder: (context, child) {
            final verticalTranslation =
                calculateVerticalTranslation(index, logic.fabAnimation.value);
            return Positioned(
              left: 0,
              right: 0,
              bottom: verticalTranslation,
              child: Opacity(
                opacity: logic.fabAnimation.value,
                child: child!,
              ),
            );
          },
          child: GestureDetector(
            onTap: onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  decoration: ShapeDecoration(
                    shape: const RoundedRectangleBorder(
                        borderRadius: AppBorderRadius.smallBorderRadius),
                    color: colorScheme.secondaryContainer,
                    shadows: [
                      BoxShadow(
                        color:
                            colorScheme.shadow.withAlpha((255 * 0.1).toInt()),
                        offset: const Offset(0, 2),
                        blurRadius: 2,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 4.0),
                  child: Text(
                    label,
                    style: textStyle.labelMedium!
                        .copyWith(color: colorScheme.onSecondaryContainer),
                  ),
                ),
                Container(
                  decoration: ShapeDecoration(
                    shape: const RoundedRectangleBorder(
                        borderRadius: AppBorderRadius.largeBorderRadius),
                    color: colorScheme.primaryContainer,
                    shadows: [
                      BoxShadow(
                        color:
                            colorScheme.shadow.withAlpha((255 * 0.1).toInt()),
                        offset: const Offset(0, 2),
                        blurRadius: 2,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  width: 56.0,
                  height: 46.0,
                  alignment: Alignment.center,
                  child: FaIcon(
                    iconData,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget buildFabButton() {
      return AnimatedBuilder(
          animation: logic.fabAnimation,
          builder: (context, child) {
            return GestureDetector(
              onTap: state.isFabExpanded ? logic.closeFab : logic.openFab,
              child: Container(
                width: 56.0,
                height: 56.0,
                // key: state.fabKey,
                decoration: ShapeDecoration(
                    shape: const RoundedRectangleBorder(
                        borderRadius: AppBorderRadius.largeBorderRadius),
                    color: Color.lerp(
                        colorScheme.primaryContainer,
                        colorScheme.surfaceContainerHighest,
                        logic.fabAnimation.value),
                    shadows: [
                      BoxShadow(
                        color:
                            colorScheme.shadow.withAlpha((255 * 0.1).toInt()),
                        offset: const Offset(0, 2),
                        blurRadius: 2,
                        spreadRadius: 2,
                      ),
                    ]),
                child: Transform.rotate(
                    angle: 3 * pi / 4 * logic.fabAnimation.value,
                    child: Icon(
                      FontAwesomeIcons.plus,
                      color: Color.lerp(colorScheme.onPrimaryContainer,
                          colorScheme.onSurface, logic.fabAnimation.value),
                    )),
              ),
            );
          });
    }

    Widget buildDiaryFab() {
      return SizedBox(
        height: 56 + 46 + 46 + 16,
        width: 56 + 32 + textStyle.labelMedium!.fontSize! * 3,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            buildToTopButton(),
            buildAnimatedActionButton(
                label: '纯文字',
                onTap: () async {
                  await logic.toEditPage(type: DiaryType.text);
                },
                iconData: FontAwesomeIcons.font,
                index: 2),
            buildAnimatedActionButton(
                label: '富文本',
                onTap: () async {
                  await logic.toEditPage(type: DiaryType.richText);
                },
                iconData: FontAwesomeIcons.feather,
                index: 1),
            buildFabButton(),
          ],
        ),
      );
    }

    Widget buildFab() {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: switch (state.navigatorIndex) {
          0 => buildDiaryFab(),
          _ => const SizedBox.shrink(
              key: ValueKey('empty'),
            ),
        },
      );
    }

    // 导航栏
    final List<NavigationDestination> destinations = [
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
        selectedIcon: const Icon(UniconsSolid.layer_group),
      ),
    ];

    Widget buildNavigatorBar() {
      var navigatorBarHeight = state.navigatorBarHeight + padding.bottom;
      return size.width < 600
          ? AnimatedBuilder(
              animation: logic.barAnimation,
              builder: (context, child) {
                return SizedBox(
                  height: (navigatorBarHeight) * logic.barAnimation.value,
                  child: child,
                );
              },
              child: OverflowBox(
                maxHeight: navigatorBarHeight,
                alignment: Alignment.topCenter,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(
                            color: colorScheme.outline.withAlpha(150),
                            width: 0.5)),
                  ),
                  child: Stack(
                    children: [
                      NavigationBar(
                        destinations: destinations,
                        selectedIndex: state.navigatorIndex,
                        height: navigatorBarHeight,
                        onDestinationSelected: logic.changeNavigator,
                        labelBehavior:
                            NavigationDestinationLabelBehavior.alwaysHide,
                      ),
                      buildModal()
                    ],
                  ),
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
                destinations: destinations
                    .map((destination) =>
                        AdaptiveScaffold.toRailDestination(destination))
                    .toList(),
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
              destinations: destinations
                  .map((destination) =>
                      AdaptiveScaffold.toRailDestination(destination))
                  .toList(),
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
