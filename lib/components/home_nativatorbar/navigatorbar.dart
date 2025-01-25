import 'package:flutter/material.dart';
import 'package:moodiary/components/base/modal.dart';
import 'package:moodiary/main.dart';
import 'package:refreshed/refreshed.dart';
import 'package:unicons/unicons.dart';

class HomeNavigatorBar extends StatelessWidget {
  static const double defaultNavigatorBarHeight = 56.0;

  final Animation<double> animation;

  final RxInt navigatorIndex;

  final Function(int) onTap;

  final Modal modal;

  const HomeNavigatorBar(
      {super.key,
      required this.animation,
      required this.navigatorIndex,
      required this.onTap,
      required this.modal});

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final size = MediaQuery.sizeOf(context);
    final colorScheme = Theme.of(context).colorScheme;
    final navigatorBarHeight = defaultNavigatorBarHeight + padding.bottom;
    return Visibility(
      visible: size.width < 600,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return SizedBox(
            height: (navigatorBarHeight) * animation.value,
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
                    color: colorScheme.outline.withValues(alpha: 0.5),
                    width: 0.5),
              ),
            ),
            child: Stack(
              children: [
                Obx(() {
                  return NavigationBar(
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
                        selectedIcon: const Icon(UniconsSolid.layer_group),
                      ),
                    ],
                    selectedIndex: navigatorIndex.value,
                    height: navigatorBarHeight,
                    onDestinationSelected: onTap,
                    backgroundColor: colorScheme.surfaceContainer,
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysHide,
                  );
                }),
                modal,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
