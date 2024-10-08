import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/border.dart';
import 'package:mood_diary/components/color_dialog/color_dialog_view.dart';
import 'package:mood_diary/components/dashboard/dashboard_view.dart';
import 'package:mood_diary/components/remove_password/remove_password_view.dart';
import 'package:mood_diary/components/set_password/set_password_view.dart';
import 'package:mood_diary/components/theme_mode_dialog/theme_mode_dialog_view.dart';

import 'setting_logic.dart';

class SettingPage extends StatelessWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<SettingLogic>();
    final state = Bind.find<SettingLogic>().state;
    final textStyle = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final i18n = AppLocalizations.of(context)!;

    return GetBuilder<SettingLogic>(
      init: logic,
      assignId: true,
      builder: (logic) {
        return CustomScrollView(
          cacheExtent: 1000.0,
          slivers: [
            SliverAppBar(
              title: Text(i18n.homeNavigatorSetting),
              pinned: true,
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              sliver: SliverList.list(
                children: [
                  ListTile(
                    title: Text(
                      '管理',
                      style: textStyle.titleLarge!.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const DashboardComponent(),
                  ListTile(
                    title: Text(
                      i18n.settingData,
                      style: textStyle.titleLarge!.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Card.filled(
                    color: colorScheme.surfaceContainerLow,
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(i18n.settingRecycle),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            logic.toRecyclePage();
                          },
                          leading: const Icon(Icons.delete_outline),
                        ),
                        ListTile(
                          title: Text(i18n.settingExport),
                          onTap: () {
                            showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: Text(i18n.settingExportDialogTitle),
                                    content: Text(i18n.settingExportDialogContent),
                                    actions: [
                                      TextButton(
                                          onPressed: () {
                                            Get.backLegacy();
                                          },
                                          child: Text(i18n.cancel)),
                                      TextButton(
                                          onPressed: () async {
                                            await logic.exportFile();
                                          },
                                          child: Text(i18n.ok))
                                    ],
                                  );
                                });
                          },
                          trailing: const Icon(Icons.chevron_right),
                          leading: const Icon(Icons.file_upload_outlined),
                        ),
                        ListTile(
                          title: Text(i18n.settingImport),
                          subtitle: Text(i18n.settingImportDes),
                          onTap: () async {
                            showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: Text(i18n.settingImportDialogTitle),
                                    content: Text(i18n.settingImportDialogContent),
                                    actions: [
                                      TextButton(
                                          onPressed: () {
                                            Get.backLegacy();
                                          },
                                          child: Text(i18n.cancel)),
                                      TextButton(
                                          onPressed: () async {
                                            logic.import();
                                          },
                                          child: Text(i18n.settingImportSelectFile))
                                    ],
                                  );
                                });
                          },
                          trailing: const Icon(Icons.chevron_right),
                          leading: const Icon(Icons.file_download_outlined),
                        ),
                        ListTile(
                          title: Text(i18n.settingClean),
                          leading: const Icon(Icons.cleaning_services_outlined),
                          trailing: Obx(() {
                            return Text(
                              state.dataUsage.value,
                              style: textStyle.bodySmall!.copyWith(
                                color: colorScheme.primary,
                              ),
                            );
                          }),
                          onTap: () {
                            logic.deleteCache();
                          },
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    title: Text(
                      i18n.settingDisplay,
                      style: textStyle.titleLarge!.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Card.filled(
                    color: colorScheme.surfaceContainerLow,
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(i18n.settingThemeMode),
                          leading: const Icon(Icons.invert_colors),
                          trailing: Obx(() {
                            return Text(
                              switch (state.themeMode.value) {
                                0 => i18n.themeModeSystem,
                                1 => i18n.themeModeLight,
                                2 => i18n.themeModeDark,
                                // TODO: Handle this case.
                                int() => throw UnimplementedError()
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
                                  return const ThemeModeDialogComponent();
                                });
                          },
                        ),
                        ListTile(
                          title: Text(i18n.settingColor),
                          leading: const Icon(Icons.color_lens_outlined),
                          trailing: Obx(() {
                            return Text(
                              switch (state.color.value) {
                                0 => i18n.colorNameQunQin,
                                1 => i18n.colorNameJiHe,
                                2 => i18n.colorNameQinDai,
                                3 => i18n.colorNameXianYe,
                                4 => i18n.colorNameJinYu,
                                _ => i18n.colorNameSystem
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
                                  return const ColorDialogComponent();
                                });
                          },
                        ),
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
                                // TODO: Handle this case.
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
                        ListTile(
                          title: Text(i18n.settingFontSize),
                          leading: const Icon(Icons.format_size_outlined),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            logic.toFontSizePage();
                          },
                        ),
                        // ListTile(
                        //   title: Text(i18n.settingFontStyle),
                        //   leading: const Icon(Icons.text_format_outlined),
                        //   trailing: Obx(() {
                        //     return Text(
                        //       switch (state.fontTheme.value) {
                        //         0 => '思源黑体',
                        //         1 => '思源宋体',
                        //         // TODO: Handle this case.
                        //         int() => throw UnimplementedError(),
                        //       },
                        //       style: textStyle.bodySmall!.copyWith(
                        //         color: colorScheme.primary,
                        //       ),
                        //     );
                        //   }),
                        //   onTap: () {
                        //     showDialog(
                        //         context: context,
                        //         builder: (context) {
                        //           return Obx(() {
                        //             return SimpleDialog(
                        //               title: Text(i18n.settingFontStyle),
                        //               children: [
                        //                 SimpleDialogOption(
                        //                   child: Row(
                        //                     children: [
                        //                       const Text(
                        //                         '思源黑体',
                        //                         style: TextStyle(
                        //                             fontFamily: 'NotoSans SC', fontFamilyFallback: ['NotoSans SC']),
                        //                       ),
                        //                       const SizedBox(
                        //                         width: 10,
                        //                       ),
                        //                       if (state.fontTheme.value == 0) ...[
                        //                         const Icon(Icons.check),
                        //                       ]
                        //                     ],
                        //                   ),
                        //                   onPressed: () {
                        //                     logic.changeFontTheme(0);
                        //                   },
                        //                 ),
                        //                 SimpleDialogOption(
                        //                   child: Row(
                        //                     children: [
                        //                       const Text(
                        //                         '思源宋体',
                        //                         style: TextStyle(
                        //                             fontFamily: 'NotoSerif SC', fontFamilyFallback: ['NotoSerif SC']),
                        //                       ),
                        //                       const SizedBox(
                        //                         width: 10,
                        //                       ),
                        //                       if (state.fontTheme.value == 1) ...[
                        //                         const Icon(Icons.check),
                        //                       ]
                        //                     ],
                        //                   ),
                        //                   onPressed: () {
                        //                     logic.changeFontTheme(1);
                        //                   },
                        //                 ),
                        //               ],
                        //             );
                        //           });
                        //         });
                        //   },
                        // ),
                        // Obx(() {
                        //   return SwitchListTile(
                        //     value: state.getWeather.value,
                        //     onChanged: (value) {
                        //       logic.weather(value);
                        //     },
                        //     title: Text(i18n.settingWeather),
                        //     secondary: const Icon(Icons.sunny),
                        //   );
                        // }),
                        ListTile(
                          title: const Text('自定义首页名称'),
                          leading: const Icon(Icons.drive_file_rename_outline),
                          trailing: Obx(() {
                            return Text(
                              state.customTitle.value,
                              style: textStyle.bodySmall!.copyWith(
                                color: colorScheme.primary,
                              ),
                            );
                          }),
                          onTap: () {
                            showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    content: TextField(
                                      maxLines: 1,
                                      controller: logic.textEditingController,
                                      decoration: InputDecoration(
                                        fillColor: colorScheme.secondaryContainer,
                                        border: const UnderlineInputBorder(
                                          borderRadius: AppBorderRadius.smallBorderRadius,
                                          borderSide: BorderSide.none,
                                        ),
                                        filled: true,
                                        labelText: '名称',
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                          onPressed: () {
                                            logic.cancelCustomTitle();
                                          },
                                          child: Text(i18n.cancel)),
                                      TextButton(
                                          onPressed: () async {
                                            await logic.setCustomTitle();
                                          },
                                          child: Text(i18n.ok))
                                    ],
                                  );
                                });
                          },
                        )
                      ],
                    ),
                  ),
                  ListTile(
                    title: Text(
                      i18n.settingPrivacy,
                      style: textStyle.titleLarge!.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Card.filled(
                    color: colorScheme.surfaceContainerLow,
                    child: Column(
                      children: [
                        Obx(() {
                          return SwitchListTile(
                            value: state.local.value,
                            onChanged: (value) {
                              logic.local(value);
                            },
                            title: Text(i18n.settingLocal),
                            subtitle: Text(i18n.settingLocalDes),
                            secondary: const Icon(Icons.cloud_off_outlined),
                          );
                        }),
                        Obx(() {
                          return ListTile(
                            trailing: Text(
                              state.lock.value ? i18n.settingLockOpen : i18n.settingLockNotOpen,
                              style: textStyle.bodySmall!.copyWith(
                                color: colorScheme.primary,
                              ),
                            ),
                            onTap: () {
                              showDialog(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: Text(i18n.settingLock),
                                      content: Text(state.lock.value
                                          ? i18n.settingLockResetLock
                                          : i18n.settingLockChooseLockType),
                                      actions: [
                                        TextButton(
                                            onPressed: () {
                                              Get.backLegacy();
                                              showModalBottomSheet(
                                                  context: context,
                                                  isScrollControlled: true,
                                                  showDragHandle: true,
                                                  useSafeArea: true,
                                                  builder: (context) {
                                                    return state.lock.value
                                                        ? const RemovePasswordComponent()
                                                        : const SetPasswordComponent();
                                                  });
                                            },
                                            child: Text(state.lock.value ? '关闭' : '数字')),
                                      ],
                                    );
                                  });
                            },
                            title: Text(i18n.settingLock),
                            leading: const Icon(Icons.lock_outline),
                          );
                        }),
                        Obx(() {
                          return SwitchListTile(
                            value: state.lockNow.value,
                            onChanged: state.lock.value
                                ? (value) {
                                    logic.lockNow(value);
                                  }
                                : null,
                            title: Text(i18n.settingLockNow),
                            subtitle: Text(i18n.settingLockNowDes),
                            secondary: const Icon(Icons.lock_clock_outlined),
                          );
                        }),
                      ],
                    ),
                  ),
                  ListTile(
                    title: Text(
                      i18n.settingMore,
                      style: textStyle.titleLarge!.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Card.filled(
                    color: colorScheme.surfaceContainerLow,
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(i18n.settingAbout),
                          leading: const Icon(Icons.info_outline),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            logic.toAboutPage();
                          },
                        ),
                        ListTile(
                          title: Text(i18n.settingLab),
                          leading: const Icon(Icons.science_outlined),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            logic.toLaboratoryPage();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
