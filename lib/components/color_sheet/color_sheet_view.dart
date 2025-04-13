import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/values/border.dart';
import 'package:moodiary/common/values/colors.dart';
import 'package:moodiary/components/base/marquee.dart';
import 'package:moodiary/l10n/l10n.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/utils/theme_util.dart';

import 'color_sheet_logic.dart';
import 'color_sheet_state.dart';

class ColorSheetComponent extends StatelessWidget {
  const ColorSheetComponent({super.key});

  Widget buildColorOption({
    required BuildContext context,
    required int currentColor,
    required int realIndex,
    required Brightness brightness,
    required TextStyle? textStyle,
    required VoidCallback onTap,
    required BoxConstraints constraints,
    bool isSystemColor = false,
  }) {
    final customColorScheme =
        isSystemColor
            ? (brightness == Brightness.light
                ? ThemeUtil().lightDynamic!
                : ThemeUtil().darkDynamic!)
            : ColorScheme.fromSeed(
              seedColor: AppColor.themeColorList[realIndex],
              dynamicSchemeVariant:
                  (realIndex == 0)
                      ? DynamicSchemeVariant.monochrome
                      : DynamicSchemeVariant.tonalSpot,
              brightness: brightness,
            );

    final textPainter = TextPainter(
      text: TextSpan(
        text: AppColor.colorName(realIndex, context),
        style: textStyle,
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.linear(PrefUtil.getValue<double>('fontScale')!),
    )..layout();
    final showMarquee = textPainter.width > constraints.maxWidth - 8.0;
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Ink(
        decoration: BoxDecoration(
          color: customColorScheme.primary,
          borderRadius: AppBorderRadius.mediumBorderRadius,
        ),
        child: InkWell(
          borderRadius: AppBorderRadius.mediumBorderRadius,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Stack(
            children: [
              AnimatedPositioned(
                left:
                    currentColor == realIndex
                        ? 6
                        : (constraints.maxWidth / 2 -
                            textPainter.width / 2 -
                            4.0),
                bottom:
                    currentColor == realIndex
                        ? 6
                        : (constraints.maxHeight / 2 -
                            textPainter.height / 2 -
                            4.0),
                duration: const Duration(milliseconds: 300),
                child:
                    showMarquee
                        ? SizedBox(
                          height: textPainter.height,
                          width: constraints.maxWidth - 8.0,
                          child: Marquee(
                            text: AppColor.colorName(realIndex, context),
                            velocity: 20,
                            blankSpace: 20,
                            pauseAfterRound: const Duration(seconds: 1),
                            accelerationDuration: const Duration(seconds: 1),
                            accelerationCurve: Curves.linear,
                            decelerationDuration: const Duration(
                              milliseconds: 500,
                            ),
                            decelerationCurve: Curves.easeOut,
                            style: textStyle?.copyWith(
                              color: customColorScheme.onPrimary,
                            ),
                          ),
                        )
                        : Text(
                          AppColor.colorName(realIndex, context),
                          style: textStyle?.copyWith(
                            color: customColorScheme.onPrimary,
                          ),
                        ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: AnimatedOpacity(
                  opacity: currentColor == realIndex ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    Icons.check_circle,
                    size: 12,
                    color: customColorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorSheetLogic logic = Get.put(ColorSheetLogic());
    final ColorSheetState state = Bind.find<ColorSheetLogic>().state;

    // 绘制普通配色
    Widget buildCommonColor() {
      final hasSystemColor = ThemeUtil().supportDynamic;
      final itemCount =
          hasSystemColor
              ? AppColor.themeColorList.length + 1
              : AppColor.themeColorList.length;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              context.l10n.colorCommon,
              style: context.textTheme.titleMedium,
            ),
          ),
          GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 64,
              childAspectRatio: 1.0,
            ),
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemBuilder: (context, index) {
              final realIndex = hasSystemColor ? index - 1 : index;
              return LayoutBuilder(
                builder: (context, constraints) {
                  return buildColorOption(
                    context: context,
                    currentColor: state.currentColor,
                    realIndex: realIndex,
                    brightness: context.theme.colorScheme.brightness,
                    textStyle: context.textTheme.labelMedium,
                    isSystemColor: realIndex == -1,
                    constraints: constraints,
                    onTap: () {
                      logic.changeSeedColor(realIndex);
                    },
                  );
                },
              );
            },
            itemCount: itemCount,
          ),
        ],
      );
    }

    // 绘制特殊配色
    // Widget buildSpecialColor() {
    //   return Column(
    //     crossAxisAlignment: CrossAxisAlignment.start,
    //     mainAxisSize: MainAxisSize.min,
    //     children: [
    //       Padding(
    //         padding: const EdgeInsets.all(8.0),
    //         child: Text(
    //           '特殊配色',
    //           style: textStyle.titleMedium,
    //         ),
    //       ),
    //       GridView.builder(
    //         gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
    //           maxCrossAxisExtent: 64,
    //           childAspectRatio: 1.0,
    //         ),
    //         physics: const NeverScrollableScrollPhysics(),
    //         padding: EdgeInsets.zero,
    //         shrinkWrap: true,
    //         itemBuilder: (context, index) {
    //           return const SizedBox.shrink();
    //         },
    //         itemCount: 0,
    //       ),
    //     ],
    //   );
    // }

    return GetBuilder<ColorSheetLogic>(
      assignId: true,
      builder: (_) {
        return ListView(
          padding: const EdgeInsets.all(8.0),
          children: [buildCommonColor()],
        );
      },
    );
  }
}
