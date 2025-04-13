import 'dart:math';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/values/border.dart';
import 'package:moodiary/l10n/l10n.dart';

class HomeFabComponent extends StatelessWidget {
  final Animation<double> animation;

  final RxBool shouldShow;

  final RxBool isToTopShow;

  final RxBool isExpanded;

  final Function() closeFab;
  final Function() openFab;

  final Function() toTop;
  final Function() toMarkdown;
  final Function() toPlainText;
  final Function() toRichText;

  final bool showShadow;

  const HomeFabComponent({
    super.key,
    required this.animation,
    required this.shouldShow,
    required this.isToTopShow,
    required this.isExpanded,
    required this.toTop,
    required this.toMarkdown,
    required this.toPlainText,
    required this.toRichText,
    required this.closeFab,
    required this.openFab,
    required this.showShadow,
  });

  @override
  Widget build(BuildContext context) {
    Widget buildToTopButton() {
      return Obx(() {
        return Visibility(
          visible: isToTopShow.value && !isExpanded.value,
          child: Transform(
            transform: Matrix4.identity()..translate(.0, -(56.0 + 8.0)),
            alignment: FractionalOffset.center,
            child: GestureDetector(
              onTap: toTop,
              child: Container(
                decoration: ShapeDecoration(
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppBorderRadius.largeBorderRadius,
                  ),
                  color: context.theme.colorScheme.tertiaryContainer,
                  shadows: [
                    BoxShadow(
                      color: context.theme.colorScheme.shadow.withAlpha(
                        (255 * 0.1).toInt(),
                      ),
                      offset: const Offset(0, 2),
                      blurRadius: 2,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                width: 56.0,
                height: 56.0,
                child: Center(
                  child: FaIcon(
                    FontAwesomeIcons.arrowUp,
                    color: context.theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ),
          ),
        );
      });
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

      final button = [
        Container(
          decoration: ShapeDecoration(
            shape: const RoundedRectangleBorder(
              borderRadius: AppBorderRadius.smallBorderRadius,
            ),
            color: context.theme.colorScheme.secondaryContainer,
            shadows: [
              BoxShadow(
                color: context.theme.colorScheme.shadow.withAlpha(
                  (255 * 0.1).toInt(),
                ),
                offset: const Offset(0, 2),
                blurRadius: 2,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 4.0),
          child: Text(
            label,
            style: context.textTheme.labelMedium!.copyWith(
              color: context.theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ),
        Container(
          decoration: ShapeDecoration(
            shape: const RoundedRectangleBorder(
              borderRadius: AppBorderRadius.largeBorderRadius,
            ),
            color: context.theme.colorScheme.primaryContainer,
            shadows: [
              BoxShadow(
                color: context.theme.colorScheme.shadow.withAlpha(
                  (255 * 0.1).toInt(),
                ),
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
            color: context.theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ];
      return Obx(() {
        return Visibility(
          visible: isExpanded.value,
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final verticalTranslation = calculateVerticalTranslation(
                index,
                animation.value,
              );
              return Positioned(
                right: 0,
                bottom: verticalTranslation,
                child: Opacity(opacity: animation.value, child: child!),
              );
            },
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.translucent,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                spacing: 16.0,
                children: button,
              ),
            ),
          ),
        );
      });
    }

    Widget buildFabButton(bool showShadow) {
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return GestureDetector(
            onTap: isExpanded.value ? closeFab : openFab,
            child: Container(
              width: 56.0,
              height: 56.0,
              decoration: ShapeDecoration(
                shape: const RoundedRectangleBorder(
                  borderRadius: AppBorderRadius.largeBorderRadius,
                ),
                color: Color.lerp(
                  context.theme.colorScheme.primaryContainer,
                  context.theme.colorScheme.surfaceContainerHighest,
                  animation.value,
                ),
                shadows:
                    showShadow
                        ? [
                          BoxShadow(
                            color: context.theme.colorScheme.shadow.withAlpha(
                              (255 * 0.1).toInt(),
                            ),
                            offset: const Offset(0, 2),
                            blurRadius: 2,
                            spreadRadius: 2,
                          ),
                        ]
                        : null,
              ),
              child: Transform.rotate(
                angle: 3 * pi / 4 * animation.value,
                child: Icon(
                  FontAwesomeIcons.plus,
                  color: Color.lerp(
                    context.theme.colorScheme.onPrimaryContainer,
                    context.theme.colorScheme.onSurface,
                    animation.value,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    Widget buildDiaryFab(bool showShadow) {
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return SizedBox(
            height: 56 + 8 + 56 + ((46 + 8) * 3 - 56 - 8) * (animation.value),
            child: child,
          );
        },
        child: Stack(
          alignment: Alignment.bottomRight,
          clipBehavior: Clip.none,
          children: [
            buildToTopButton(),
            buildAnimatedActionButton(
              label: context.l10n.homeNewDiaryMarkdown,
              onTap: toMarkdown,
              iconData: FontAwesomeIcons.markdown,
              index: 3,
            ),
            buildAnimatedActionButton(
              label: context.l10n.homeNewDiaryPlainText,
              onTap: toPlainText,
              iconData: FontAwesomeIcons.font,
              index: 2,
            ),
            buildAnimatedActionButton(
              label: context.l10n.homeNewDiaryRichText,
              onTap: toRichText,
              iconData: FontAwesomeIcons.feather,
              index: 1,
            ),
            buildFabButton(showShadow),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Obx(() {
          return Visibility(
            visible: shouldShow.value && constraints.maxWidth < 600,
            child: RepaintBoundary(child: buildDiaryFab(showShadow)),
          );
        });
      },
    );
  }
}

class DesktopHomeFabComponent extends StatelessWidget {
  final RxBool isToTopShow;

  final Function() toTop;
  final Function() toMarkdown;
  final Function() toPlainText;
  final Function() toRichText;

  const DesktopHomeFabComponent({
    super.key,
    required this.isToTopShow,
    required this.toTop,
    required this.toMarkdown,
    required this.toPlainText,
    required this.toRichText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        spacing: 16.0,
        children: [
          Obx(() {
            return Visibility(
              visible: isToTopShow.value,
              child: IconButton(
                onPressed: toTop,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
            );
          }),
          IconButton.filled(
            onPressed: toMarkdown,
            icon: const FaIcon(FontAwesomeIcons.markdown, size: 16),
            style: const ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            tooltip: context.l10n.homeNewDiaryMarkdown,
          ),
          IconButton.filled(
            onPressed: toPlainText,
            icon: const FaIcon(FontAwesomeIcons.font, size: 16),
            style: const ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            tooltip: context.l10n.homeNewDiaryPlainText,
          ),
          IconButton.filled(
            onPressed: toRichText,
            icon: const FaIcon(FontAwesomeIcons.feather, size: 16),
            style: const ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            tooltip: context.l10n.homeNewDiaryRichText,
          ),
          Text(
            context.l10n.appName,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
