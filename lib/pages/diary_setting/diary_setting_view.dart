import 'package:flutter/material.dart';
import 'package:moodiary/components/base/button.dart';
import 'package:moodiary/components/tile/setting_tile.dart';
import 'package:moodiary/main.dart';
import 'package:refreshed/refreshed.dart';

import 'diary_setting_logic.dart';

class DiarySettingPage extends StatelessWidget {
  const DiarySettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<DiarySettingLogic>();
    final state = Bind.find<DiarySettingLogic>().state;
    final textStyle = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // 通用设置
    List<Widget> buildCommon() {
      return [
        AdaptiveTitleTile(
          title: l10n.diarySettingCommon,
          subtitle: l10n.diarySettingCommonDes,
        ),
        Card.filled(
          color: colorScheme.surfaceContainerLow,
          child: Column(
            children: [
              Obx(() {
                return AdaptiveSwitchListTile(
                  value: state.autoWeather.value,
                  isFirst: true,
                  onChanged: (value) {
                    logic.autoWeather(value);
                  },
                  title: l10n.diarySettingAutoGetWeather,
                  secondary: const Icon(Icons.wb_sunny_rounded),
                );
              }),
              Obx(() {
                return AdaptiveSwitchListTile(
                  value: state.autoCategory.value,
                  onChanged: logic.autoCategory,
                  secondary: const Icon(Icons.category_rounded),
                  title: l10n.diarySettingAutoSetCategory,
                );
              }),
              Obx(() {
                return AdaptiveSwitchListTile(
                  value: state.showWriteTime.value,
                  onChanged: logic.showWriteTime,
                  secondary: const Icon(Icons.timer_rounded),
                  title: l10n.diarySettingShowWritingTime,
                );
              }),
              Obx(() {
                return AdaptiveSwitchListTile(
                  value: state.showWordCount.value,
                  onChanged: logic.showWordCount,
                  secondary: const Icon(Icons.font_download_rounded),
                  title: l10n.diarySettingShowWriteCount,
                );
              }),
              Obx(() {
                return AdaptiveSwitchListTile(
                  value: state.dynamicColor.value,
                  onChanged: logic.dynamicColor,
                  secondary: const Icon(Icons.colorize_rounded),
                  isLast: true,
                  title: l10n.diarySettingDynamicColor,
                  subtitle: l10n.diarySettingDynamicColorDes,
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
          title: l10n.diarySettingPlainText,
          subtitle: l10n.diarySettingPlainTextDes,
        ),
        Card.filled(
          color: colorScheme.surfaceContainerLow,
          child: Column(
            children: [
              Obx(() {
                return AdaptiveSwitchListTile(
                  value: state.firstLineIndent.value,
                  onChanged: logic.firstLineIndent,
                  title: l10n.diarySettingFirstLineIndent,
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
          title: l10n.diarySettingRichText,
          subtitle: l10n.diarySettingRichTextDes,
        ),
        Card.filled(
          color: colorScheme.surfaceContainerLow,
          child: Column(
            children: [
              AdaptiveListTile(
                title: l10n.settingImageQuality,
                subtitle: l10n.settingImageQualityDes,
                isFirst: true,
                leading: const Icon(Icons.gradient_rounded),
                trailing: Obx(() {
                  return Text(
                    switch (state.quality.value) {
                      0 => l10n.qualityLow,
                      1 => l10n.qualityMedium,
                      2 => l10n.qualityHigh,
                      3 => l10n.qualityOriginal,
                      int() => throw UnimplementedError(),
                    },
                    style: textStyle.bodySmall!.copyWith(
                      color: colorScheme.primary,
                    ),
                  );
                }),
                onTap: () {
                  showDialog(
                      context: context,
                      builder: (context) {
                        return Obx(() {
                          return SimpleDialog(
                            title: Text(l10n.settingImageQuality),
                            children: [
                              SimpleDialogOption(
                                child: Row(
                                  spacing: 8.0,
                                  children: [
                                    Text(l10n.qualityLow),
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
                                    Text(l10n.qualityMedium),
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
                                    Text(l10n.qualityHigh),
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
                                    Text(l10n.qualityOriginal),
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
                      });
                },
              ),
              Obx(() {
                return AdaptiveSwitchListTile(
                  value: state.diaryHeader.value,
                  onChanged: logic.diaryHeader,
                  isLast: true,
                  title: l10n.diarySettingShowHeaderImage,
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
        title: Text(l10n.settingDiary),
        leading: const PageBackButton(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(4.0),
          children: [...buildRichText(), ...buildPureText(), ...buildCommon()],
        ),
      ),
    );
  }
}
