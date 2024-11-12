import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get/get.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('日记个性化'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text(i18n.settingImageQuality),
            subtitle: Text(i18n.settingImageQualityDes),
            leading: const Icon(Icons.gradient_outlined),
            trailing: GetBuilder<DiarySettingLogic>(
                id: 'Quality',
                builder: (_) {
                  return Text(
                    switch (state.quality) {
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
                    return GetBuilder<DiarySettingLogic>(
                        id: 'Quality',
                        builder: (_) {
                          return SimpleDialog(
                            title: Text(i18n.settingImageQuality),
                            children: [
                              SimpleDialogOption(
                                child: Row(
                                  spacing: 8.0,
                                  children: [
                                    Text(i18n.qualityLow),
                                    if (state.quality == 0) ...[
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
                                    if (state.quality == 1) ...[
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
                                    if (state.quality == 2) ...[
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
          GetBuilder<DiarySettingLogic>(
              id: 'AutoWeather',
              builder: (_) {
                return SwitchListTile(
                  value: state.autoWeather,
                  onChanged: (value) {
                    logic.autoWeather(value);
                  },
                  title: const Text('自动获取天气'),
                  secondary: const Icon(Icons.sunny),
                );
              })
        ],
      ),
    );
  }
}
