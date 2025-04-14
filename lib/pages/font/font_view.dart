import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/values/border.dart';
import 'package:moodiary/components/base/button.dart';
import 'package:moodiary/components/base/loading.dart';
import 'package:moodiary/components/base/text.dart';
import 'package:moodiary/components/base/tile/setting_tile.dart';
import 'package:moodiary/l10n/l10n.dart';

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
                width: isSelected ? 2 : 1,
              ),
            ),
            width: 64,
            height: 64,
            child: const Center(
              child: Text('Aa', style: TextStyle(fontSize: 32, fontFamily: '')),
            ),
          ),
        ),
        AdaptiveText(context.l10n.fontStyleSystem, style: textStyle),
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
                width: isSelected ? 2 : 1,
              ),
            ),
            width: 64,
            height: 64,
            child: Center(
              child: Text(
                'Aa',
                style: TextStyle(fontSize: 32, fontFamily: fontName),
              ),
            ),
          ),
        ),
        AdaptiveText(fontName, style: textStyle, maxWidth: 64),
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
              borderRadius: AppBorderRadius.mediumBorderRadius,
              color: color,
            ),
            width: 64,
            height: 64,
            child: const Center(child: Icon(Icons.add_circle_rounded)),
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

    final viewPadding = MediaQuery.viewPaddingOf(context);
    final size = MediaQuery.sizeOf(context);

    Widget buildText() {
      return ListView(
        children: [
          Obx(() {
            return Text(
              '八月的忧愁',
              style: context.textTheme.titleLarge?.copyWith(
                height: 2,
                fontFamily: state.currentFontFamily.value,
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
              style: context.textTheme.bodyMedium?.copyWith(
                height: 2,
                fontFamily: state.currentFontFamily.value,
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
          isSelected: state.currentFontFamily.value == '',
          activeColor: context.theme.colorScheme.primary,
          inactiveColor: context.theme.colorScheme.surfaceContainerHighest,
          textStyle: context.textTheme.labelSmall,
          context: context,
          onTap: () {
            logic.changeSelectedFont(font: null);
          },
        ),
        ...List.generate(state.fontList.length, (index) {
          return _buildFont(
            isSelected:
                state.currentFontFamily.value ==
                state.fontList[index].fontFamily,
            fontName: state.fontList[index].fontFamily,
            activeColor: context.theme.colorScheme.primary,
            inactiveColor: context.theme.colorScheme.surfaceContainerHighest,
            textStyle: context.textTheme.labelSmall,
            context: context,
            onTap: () {
              logic.changeSelectedFont(font: state.fontList[index]);
            },
            onLongPress: () async {
              // 显示删除字体对话框
              final res = showOkCancelAlertDialog(
                context: context,
                title: context.l10n.hint,
                style: AdaptiveStyle.material,
                message: context.l10n.fontDeleteDes(
                  state.fontList[index].fontFamily,
                ),
              );
              if (await res == OkCancelResult.ok) {
                logic.deleteFont(font: state.fontList[index]);
              }
            },
          );
        }),
        _buildManage(
          onTap: logic.addFont,
          color: context.theme.colorScheme.surfaceContainer,
          iconColor: context.theme.colorScheme.onSurface,
        ),
      ];
    }

    Widget buildOption() {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child:
                size.width < 600
                    ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Obx(() {
                        return Row(spacing: 16, children: buildFontButton());
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
                  Text(context.l10n.fontStyleSize),
                  Text(switch (state.fontScale.value) {
                    0.8 => context.l10n.fontSizeSuperSmall,
                    0.9 => context.l10n.fontSizeSmall,
                    1.0 => context.l10n.fontSizeStandard,
                    1.1 => context.l10n.fontSizeLarge,
                    1.2 => context.l10n.fontSizeSuperLarge,
                    _ => context.l10n.fontSizeStandard,
                  }),
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
            title: Text(context.l10n.settingFontStyle),
            leading: const PageBackButton(),
            backgroundColor: context.theme.colorScheme.surfaceContainerLow,
          ),
          backgroundColor: context.theme.colorScheme.surfaceContainerLow,
          body:
              size.width < 600
                  ? Obx(() {
                    return !state.isFetching.value
                        ? Padding(
                          padding: EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: state.bottomSheetHeight.value,
                          ),
                          child: buildText(),
                        )
                        : const MoodiaryLoading();
                  })
                  : Obx(() {
                    return !state.isFetching.value
                        ? RepaintBoundary(
                          child: Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 16,
                                    right: 16,
                                  ),
                                  child: buildText(),
                                ),
                              ),
                              Expanded(child: buildOption()),
                            ],
                          ),
                        )
                        : const MoodiaryLoading();
                  }),
          resizeToAvoidBottomInset: false,
          floatingActionButton:
              size.width > 600
                  ? FloatingActionButton.extended(
                    onPressed: logic.saveFontScale,
                    label: Text(context.l10n.apply),
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
                  color: context.theme.colorScheme.surface,
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
                              color:
                                  context
                                      .theme
                                      .colorScheme
                                      .surfaceContainerHighest,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(2.50),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: buildOption()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: FilledButton(
                        onPressed: logic.saveFontScale,
                        child: Text(context.l10n.apply),
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
