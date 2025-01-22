import 'dart:math';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:moodiary/common/values/border.dart';
import 'package:moodiary/main.dart';
import 'package:refreshed/refreshed.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme;

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
                        borderRadius: AppBorderRadius.largeBorderRadius),
                    color: colorScheme.tertiaryContainer,
                    shadows: [
                      BoxShadow(
                          color:
                              colorScheme.shadow.withAlpha((255 * 0.1).toInt()),
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
                borderRadius: AppBorderRadius.smallBorderRadius),
            color: colorScheme.secondaryContainer,
            shadows: [
              BoxShadow(
                color: colorScheme.shadow.withAlpha((255 * 0.1).toInt()),
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
                color: colorScheme.shadow.withAlpha((255 * 0.1).toInt()),
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
      ];
      return Obx(() {
        return Visibility(
          visible: isExpanded.value,
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final verticalTranslation =
                  calculateVerticalTranslation(index, animation.value);
              return Positioned(
                right: 0,
                bottom: verticalTranslation,
                child: Opacity(
                  opacity: animation.value,
                  child: child!,
                ),
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
                        borderRadius: AppBorderRadius.largeBorderRadius),
                    color: Color.lerp(colorScheme.primaryContainer,
                        colorScheme.surfaceContainerHighest, animation.value),
                    shadows: showShadow
                        ? [
                            BoxShadow(
                              color: colorScheme.shadow
                                  .withAlpha((255 * 0.1).toInt()),
                              offset: const Offset(0, 2),
                              blurRadius: 2,
                              spreadRadius: 2,
                            ),
                          ]
                        : null),
                child: Transform.rotate(
                    angle: 3 * pi / 4 * animation.value,
                    child: Icon(
                      FontAwesomeIcons.plus,
                      color: Color.lerp(colorScheme.onPrimaryContainer,
                          colorScheme.onSurface, animation.value),
                    )),
              ),
            );
          });
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
                label: l10n.homeNewDiaryMarkdown,
                onTap: toMarkdown,
                iconData: FontAwesomeIcons.markdown,
                index: 3),
            buildAnimatedActionButton(
                label: l10n.homeNewDiaryPlainText,
                onTap: toPlainText,
                iconData: FontAwesomeIcons.font,
                index: 2),
            buildAnimatedActionButton(
                label: l10n.homeNewDiaryRichText,
                onTap: toRichText,
                iconData: FontAwesomeIcons.feather,
                index: 1),
            buildFabButton(showShadow),
          ],
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      return Obx(() {
        return Visibility(
          visible: shouldShow.value && constraints.maxWidth < 600,
          child: RepaintBoundary(child: buildDiaryFab(false)),
        );
      });
    });
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
                  icon: const Icon(Icons.arrow_upward_rounded)),
            );
          }),
          IconButton.filled(
            onPressed: toMarkdown,
            icon: const FaIcon(
              FontAwesomeIcons.markdown,
              size: 16,
            ),
            style: const ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          ),
          IconButton.filled(
            onPressed: toPlainText,
            icon: const FaIcon(
              FontAwesomeIcons.font,
              size: 16,
            ),
            style: const ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          ),
          IconButton.filled(
            onPressed: toRichText,
            icon: const FaIcon(
              FontAwesomeIcons.feather,
              size: 16,
            ),
            style: const ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          ),
        ],
      ),
    );
  }
}
