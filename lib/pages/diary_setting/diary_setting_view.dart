import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/components/base/button.dart';
import 'package:moodiary/components/base/clipper.dart';
import 'package:moodiary/components/tile/setting_tile.dart';
import 'package:moodiary/l10n/l10n.dart';

import 'diary_setting_logic.dart';

class DiarySettingPage extends StatelessWidget {
  const DiarySettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<DiarySettingLogic>();
    final state = Bind.find<DiarySettingLogic>().state;

    // 通用设置
    List<Widget> buildCommon() {
      return [
        AdaptiveTitleTile(
          title: context.l10n.diarySettingCommon,
          subtitle: context.l10n.diarySettingCommonDes,
        ),
        Card.filled(
          color: context.theme.colorScheme.surfaceContainerLow,
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              Obx(() {
                return AdaptiveSwitchListTile(
                  value: state.autoWeather.value,
                  isFirst: true,
                  onChanged: (value) {
                    logic.autoWeather(value);
                  },
                  title: context.l10n.diarySettingAutoGetWeather,
                  secondary: const Icon(Icons.wb_sunny_rounded),
                );
              }),
              Obx(() {
                return AdaptiveSwitchListTile(
                  value: state.autoCategory.value,
                  onChanged: logic.autoCategory,
                  secondary: const Icon(Icons.category_rounded),
                  title: context.l10n.diarySettingAutoSetCategory,
                );
              }),
              Obx(() {
                return AdaptiveSwitchListTile(
                  value: state.showWriteTime.value,
                  onChanged: logic.showWriteTime,
                  secondary: const Icon(Icons.timer_rounded),
                  title: context.l10n.diarySettingShowWritingTime,
                );
              }),
              Obx(() {
                return AdaptiveSwitchListTile(
                  value: state.showWordCount.value,
                  onChanged: logic.showWordCount,
                  secondary: const Icon(Icons.font_download_rounded),
                  title: context.l10n.diarySettingShowWriteCount,
                );
              }),
              Obx(() {
                return AdaptiveSwitchListTile(
                  value: state.dynamicColor.value,
                  onChanged: logic.dynamicColor,
                  secondary: const Icon(Icons.colorize_rounded),
                  isLast: true,
                  title: context.l10n.diarySettingDynamicColor,
                  subtitle: context.l10n.diarySettingDynamicColorDes,
                );
              }),
            ],
          ),
        ),
      ];
    }

    List<Widget> buildPureText() {
      return [
        AdaptiveTitleTile(
          title: context.l10n.diarySettingPlainText,
          subtitle: context.l10n.diarySettingPlainTextDes,
        ),
        Card.filled(
          color: context.theme.colorScheme.surfaceContainerLow,
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              Obx(() {
                return AdaptiveSwitchListTile(
                  value: state.firstLineIndent.value,
                  onChanged: logic.firstLineIndent,
                  title: context.l10n.diarySettingFirstLineIndent,
                  isSingle: true,
                  secondary: const Icon(Icons.format_indent_increase_rounded),
                );
              }),
            ],
          ),
        ),
      ];
    }

    List<Widget> buildRichText() {
      return [
        AdaptiveTitleTile(
          title: context.l10n.diarySettingRichText,
          subtitle: context.l10n.diarySettingRichTextDes,
        ),
        Card.filled(
          color: context.theme.colorScheme.surfaceContainerLow,
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              AdaptiveListTile(
                title: context.l10n.settingImageQuality,
                subtitle: context.l10n.settingImageQualityDes,
                isFirst: true,
                leading: const Icon(Icons.gradient_rounded),
                trailing: Obx(() {
                  return Text(
                    switch (state.quality.value) {
                      0 => context.l10n.qualityLow,
                      1 => context.l10n.qualityMedium,
                      2 => context.l10n.qualityHigh,
                      3 => context.l10n.qualityOriginal,
                      int() => throw UnimplementedError(),
                    },
                    style: context.textTheme.bodySmall!.copyWith(
                      color: context.theme.colorScheme.primary,
                    ),
                  );
                }),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return Obx(() {
                        return SimpleDialog(
                          title: Text(context.l10n.settingImageQuality),
                          children: [
                            SimpleDialogOption(
                              child: Row(
                                spacing: 8.0,
                                children: [
                                  Text(context.l10n.qualityLow),
                                  if (state.quality.value == 0) ...[
                                    const Icon(Icons.check_rounded),
                                  ],
                                ],
                              ),
                              onPressed: () {
                                logic.quality(0);
                              },
                            ),
                            SimpleDialogOption(
                              child: Row(
                                spacing: 8.0,
                                children: [
                                  Text(context.l10n.qualityMedium),
                                  if (state.quality.value == 1) ...[
                                    const Icon(Icons.check_rounded),
                                  ],
                                ],
                              ),
                              onPressed: () {
                                logic.quality(1);
                              },
                            ),
                            SimpleDialogOption(
                              child: Row(
                                spacing: 8.0,
                                children: [
                                  Text(context.l10n.qualityHigh),
                                  if (state.quality.value == 2) ...[
                                    const Icon(Icons.check_rounded),
                                  ],
                                ],
                              ),
                              onPressed: () {
                                logic.quality(2);
                              },
                            ),
                            SimpleDialogOption(
                              child: Row(
                                spacing: 8.0,
                                children: [
                                  Text(context.l10n.qualityOriginal),
                                  if (state.quality.value == 3) ...[
                                    const Icon(Icons.check_rounded),
                                  ],
                                ],
                              ),
                              onPressed: () {
                                logic.quality(3);
                              },
                            ),
                          ],
                        );
                      });
                    },
                  );
                },
              ),
              Obx(() {
                return AdaptiveSwitchListTile(
                  value: state.diaryHeader.value,
                  onChanged: logic.diaryHeader,
                  isLast: true,
                  title: context.l10n.diarySettingShowHeaderImage,
                  secondary: const Icon(Icons.broken_image_rounded),
                );
              }),
            ],
          ),
        ),
      ];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settingDiary),
        leading: const PageBackButton(),
      ),
      body: PageClipper(
        child: ListView(
          children: [...buildRichText(), ...buildPureText(), ...buildCommon()],
        ),
      ),
    );
  }
}
