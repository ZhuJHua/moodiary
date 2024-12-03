import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get/get.dart';
import 'package:mood_diary/components/tile/setting_tile.dart';

import 'diary_setting_logic.dart';

class DiarySettingPage extends StatelessWidget {
  const DiarySettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<DiarySettingLogic>();
    final state = Bind.find<DiarySettingLogic>().state;
    final textStyle = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final i18n = AppLocalizations.of(context)!;

    // 通用设置
    List<Widget> buildCommon() {
      return [
        const SettingTitleTile(
          title: '通用',
          subtitle: '所有模式共享的设置',
        ),
        Card.filled(
          color: colorScheme.surfaceContainerLow,
          child: Column(
            children: [
              Obx(() {
                return SwitchListTile(
                  value: state.autoWeather.value,
                  onChanged: (value) {
                    logic.autoWeather(value);
                  },
                  title: const Text('自动获取天气'),
                  secondary: const Icon(Icons.wb_sunny_outlined),
                );
              }),
              Obx(() {
                return SwitchListTile(
                  value: state.autoCategory.value,
                  onChanged: logic.autoCategory,
                  secondary: const Icon(Icons.category_outlined),
                  title: const Text('自动设置分类'),
                );
              }),
              Obx(() {
                return SwitchListTile(
                  value: state.showWriteTime.value,
                  onChanged: logic.showWriteTime,
                  secondary: const Icon(Icons.timer_outlined),
                  title: const Text('展示写作时长'),
                );
              }),
              Obx(() {
                return SwitchListTile(
                  value: state.showWordCount.value,
                  onChanged: logic.showWordCount,
                  secondary: const Icon(Icons.font_download_outlined),
                  title: const Text('展示字数统计'),
                );
              }),
              Obx(() {
                return SwitchListTile(
                  value: state.dynamicColor.value,
                  onChanged: logic.dynamicColor,
                  secondary: const Icon(Icons.color_lens_outlined),
                  title: const Text('日记页动态配色'),
                  subtitle: const Text('使用基于封面的配色'),
                );
              }),
            ],
          ),
        ),
      ];
    }

    List<Widget> buildPureText() {
      return [
        const SettingTitleTile(
          title: '纯文本',
          subtitle: '去除多余干扰，享受更专注的写作体验',
        ),
        Card.filled(
          color: colorScheme.surfaceContainerLow,
          child: Column(
            children: [
              Obx(() {
                return SwitchListTile(
                  value: state.firstLineIndent.value,
                  onChanged: logic.firstLineIndent,
                  title: const Text('首行缩进'),
                  secondary: const Icon(Icons.format_indent_increase),
                  subtitle: const Text('只对修改后的日记生效'),
                );
              }),
            ],
          ),
        ),
      ];
    }

    List<Widget> buildRichText() {
      return [
        const SettingTitleTile(
          title: '富文本',
          subtitle: '支持更多样式及附件，让内容呈现更丰富',
        ),
        Card.filled(
          color: colorScheme.surfaceContainerLow,
          child: Column(
            children: [
              ListTile(
                title: Text(i18n.settingImageQuality),
                subtitle: Text(i18n.settingImageQualityDes),
                leading: const Icon(Icons.gradient_outlined),
                trailing: Obx(() {
                  return Text(
                    switch (state.quality.value) {
                      0 => i18n.qualityLow,
                      1 => i18n.qualityMedium,
                      2 => i18n.qualityHigh,
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
                            title: Text(i18n.settingImageQuality),
                            children: [
                              SimpleDialogOption(
                                child: Row(
                                  spacing: 8.0,
                                  children: [
                                    Text(i18n.qualityLow),
                                    if (state.quality.value == 0) ...[
                                      const Icon(Icons.check),
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
                                    Text(i18n.qualityMedium),
                                    if (state.quality.value == 1) ...[
                                      const Icon(Icons.check),
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
                                    Text(i18n.qualityHigh),
                                    if (state.quality.value == 2) ...[
                                      const Icon(Icons.check),
                                    ],
                                  ],
                                ),
                                onPressed: () {
                                  logic.quality(2);
                                },
                              ),
                            ],
                          );
                        });
                      });
                },
              ),
              Obx(() {
                return SwitchListTile(
                  value: state.diaryHeader.value,
                  onChanged: logic.diaryHeader,
                  title: const Text('日记页展示头图'),
                  secondary: const Icon(Icons.broken_image_outlined),
                );
              }),
            ],
          ),
        ),
      ];
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('日记个性化'),
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
