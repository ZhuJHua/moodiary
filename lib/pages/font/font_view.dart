import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mood_diary/common/values/border.dart';
import 'package:mood_diary/components/base/button.dart';
import 'package:mood_diary/components/base/text.dart';
import 'package:mood_diary/components/loading/loading.dart';
import 'package:mood_diary/components/tile/setting_tile.dart';
import 'package:mood_diary/main.dart';
import 'package:refreshed/refreshed.dart';
import 'package:rive_animated_icon/rive_animated_icon.dart';

import 'font_logic.dart';

class FontPage extends StatelessWidget {
  const FontPage({super.key});

  Widget _buildDefault({
    required bool isSelected,
    required Color activeColor,
    required Color inactiveColor,
    required TextStyle? textStyle,
    required Function onTap,
    required BuildContext context,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: 4.0,
      children: [
        GestureDetector(
          onTap: () {
            onTap.call();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: AppBorderRadius.mediumBorderRadius,
              border: Border.all(
                  color: isSelected ? activeColor : inactiveColor,
                  width: isSelected ? 2 : 1),
            ),
            width: 64,
            height: 64,
            child: const Center(
              child: Text('Aa', style: TextStyle(fontSize: 32)),
            ),
          ),
        ),
        buildAdaptiveText(
          text: l10n.fontStyleSystem,
          textStyle: textStyle,
          context: context,
        ),
      ],
    );
  }

  Widget _buildFont({
    required bool isSelected,
    required String fontName,
    required Color activeColor,
    required Color inactiveColor,
    required TextStyle? textStyle,
    required Function() onTap,
    required Function() onLongPress,
    required BuildContext context,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: 4.0,
      children: [
        GestureDetector(
          onTap: onTap,
          onLongPress: () {
            HapticFeedback.selectionClick();
            onLongPress();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: AppBorderRadius.mediumBorderRadius,
              border: Border.all(
                  color: isSelected ? activeColor : inactiveColor,
                  width: isSelected ? 2 : 1),
            ),
            width: 64,
            height: 64,
            child: Center(
              child: Text(
                'Aa',
                style: TextStyle(
                  fontSize: 32,
                  fontFamily: fontName,
                ),
              ),
            ),
          ),
        ),
        buildAdaptiveText(
          text: fontName,
          textStyle: textStyle,
          context: context,
          maxWidth: 64,
        ),
      ],
    );
  }

  Widget _buildManage({
    required Function() onTap,
    required Color color,
    required Color iconColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap.call();
          },
          child: Container(
            decoration: BoxDecoration(
                borderRadius: AppBorderRadius.mediumBorderRadius, color: color),
            width: 64,
            height: 64,
            child: Center(
              child: LoopingRiveIcon(
                riveIcon: RiveIcon.add,
                width: 32,
                height: 32,
                strokeWidth: 4,
                color: iconColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<FontLogic>();
    final state = Bind.find<FontLogic>().state;
    final textStyle = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final size = MediaQuery.sizeOf(context);

    Widget buildText() {
      return ListView(
        children: [
          Obx(() {
            return Text(
              '八月的忧愁',
              style: textStyle.titleLarge?.copyWith(
                height: 2,
                fontFamily: state.fontMap[state.currentFontPath.value] ?? '',
              ),
              textScaler: TextScaler.linear(state.fontScale.value),
            );
          }),
          Obx(() {
            return Text(
              '黄水塘里游着白鸭，\n'
              '高粱梗油青的刚高过头，\n'
              '这跳动的心怎样安插，\n'
              '田里一窄条路，八月里这忧愁？\n'
              '天是昨夜雨洗过的，山岗\n'
              '照着太阳又留一片影；\n'
              '羊跟着放羊的转进村庄，\n'
              '一大棵树荫下罩着井，又像是心！\n'
              '从没有人说过八月什么话，\n'
              '夏天过去了，也不到秋天。\n'
              '但我望着田垄，土墙上的瓜，\n'
              '仍不明白生活同梦怎样的连牵。',
              style: textStyle.bodyMedium?.copyWith(
                height: 2,
                fontFamily: state.fontMap[state.currentFontPath.value] ?? '',
              ),
              textScaler: TextScaler.linear(state.fontScale.value),
            );
          }),
        ],
      );
    }

    List<Widget> buildFontButton() {
      return [
        _buildDefault(
          isSelected: state.currentFontPath.value == '',
          activeColor: colorScheme.primary,
          inactiveColor: colorScheme.surfaceContainerHighest,
          textStyle: textStyle.labelSmall,
          context: context,
          onTap: () {
            logic.changeSelectedFontPath(path: '');
          },
        ),
        ...state.fontMap.entries.map((e) {
          return _buildFont(
              isSelected: state.currentFontPath.value == e.key,
              fontName: e.value,
              activeColor: colorScheme.primary,
              inactiveColor: colorScheme.surfaceContainerHighest,
              textStyle: textStyle.labelSmall,
              context: context,
              onTap: () {
                logic.changeSelectedFontPath(path: e.key);
              },
              onLongPress: () async {
                // 显示删除字体对话框
                var res = showOkCancelAlertDialog(
                  context: context,
                  title: l10n.hint,
                  style: AdaptiveStyle.material,
                  message: l10n.fontDeleteDes(e.value),
                );
                if (await res == OkCancelResult.ok) {
                  logic.deleteFont(fontPath: e.key);
                }
              });
        }),
        _buildManage(
          onTap: logic.addFont,
          color: colorScheme.surfaceContainer,
          iconColor: colorScheme.onSurface,
        ),
      ];
    }

    Widget buildOption() {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: size.width < 600
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Obx(() {
                      return Row(
                        spacing: 16,
                        children: buildFontButton(),
                      );
                    }),
                  )
                : Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: buildFontButton(),
                  ),
          ),
          const Divider(endIndent: 24, indent: 24),
          AdaptiveListTile(
            title: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.fontStyleSize),
                  Text(switch (state.fontScale.value) {
                    0.8 => l10n.fontSizeSuperSmall,
                    0.9 => l10n.fontSizeSmall,
                    1.0 => l10n.fontSizeStandard,
                    1.1 => l10n.fontSizeLarge,
                    1.2 => l10n.fontSizeSuperLarge,
                    _ => l10n.fontSizeStandard,
                  })
                ],
              ),
            ),
            contentPadding: EdgeInsets.zero,
            subtitle: Slider(
              value: state.fontScale.value,
              min: 0.8,
              max: 1.2,
              divisions: 4,
              onChanged: (value) {
                logic.changeFontScale(value);
              },
            ),
          ),
        ],
      );
    }

    return GetBuilder<FontLogic>(
      builder: (_) {
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.settingFontStyle),
            leading: const PageBackButton(),
            backgroundColor: colorScheme.surfaceContainerLow,
          ),
          backgroundColor: colorScheme.surfaceContainerLow,
          body: size.width < 600
              ? Obx(() {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: !state.isFetching.value
                        ? Padding(
                            padding: EdgeInsets.only(
                                left: 16,
                                right: 16,
                                bottom: state.bottomSheetHeight.value),
                            child: buildText(),
                          )
                        : const Center(
                            child: Processing(),
                          ),
                  );
                })
              : Obx(() {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: !state.isFetching.value
                        ? Row(
                            children: [
                              Expanded(
                                  child: Padding(
                                padding:
                                    const EdgeInsets.only(left: 16, right: 16),
                                child: buildText(),
                              )),
                              Expanded(child: buildOption())
                            ],
                          )
                        : const Center(
                            child: Processing(),
                          ),
                  );
                }),
          resizeToAvoidBottomInset: false,
          floatingActionButton: size.width > 600
              ? FloatingActionButton.extended(
                  onPressed: logic.saveFontScale,
                  label: Text(l10n.apply),
                  icon: const Icon(Icons.check_rounded),
                )
              : null,
          bottomSheet: Obx(() {
            return Visibility(
              visible: !state.isFetching.value && size.width < 600,
              child: Container(
                height: state.bottomSheetHeight.value,
                padding: EdgeInsets.only(bottom: viewPadding.bottom),
                decoration: ShapeDecoration(
                  color: colorScheme.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onVerticalDragUpdate: logic.onVerticalDragStart,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Container(
                            width: 68,
                            height: 5,
                            decoration: ShapeDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(2.50),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: buildOption(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: FilledButton(
                        onPressed: logic.saveFontScale,
                        child: Text(l10n.apply),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
