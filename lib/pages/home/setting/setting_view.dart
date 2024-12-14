import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/border.dart';
import 'package:mood_diary/components/color_dialog/color_dialog_view.dart';
import 'package:mood_diary/components/dashboard/dashboard_view.dart';
import 'package:mood_diary/components/remove_password/remove_password_view.dart';
import 'package:mood_diary/components/set_password/set_password_view.dart';
import 'package:mood_diary/components/theme_mode_dialog/theme_mode_dialog_view.dart';
import 'package:mood_diary/components/tile/setting_tile.dart';

import '../../../main.dart';
import 'setting_logic.dart';

class SettingPage extends StatelessWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(SettingLogic());
    final state = Bind.find<SettingLogic>().state;
    final textStyle = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final size = MediaQuery.sizeOf(context);

    Widget buildDashboard() {
      return const DashboardComponent();
    }

    Widget buildAFeatureButton({required Widget icon, required String text, required Function() onTap}) {
      return InkWell(
        onTap: onTap,
        borderRadius: AppBorderRadius.mediumBorderRadius,
        child: Card.outlined(
          color: colorScheme.surfaceContainerLow,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              icon,
              Text(
                text,
                style: textStyle.labelSmall,
              )
            ],
          ),
        ),
      );
    }

    Widget buildFeature() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SettingTitleTile(title: '功能'),
          GridView(
            gridDelegate:
                const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 100, childAspectRatio: 1.0),
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              buildAFeatureButton(
                  icon: Icon(
                    Icons.category_rounded,
                    color: colorScheme.secondary,
                  ),
                  text: '分类管理',
                  onTap: logic.toCategoryManager),
              buildAFeatureButton(
                  icon: FaIcon(
                    FontAwesomeIcons.squarePollVertical,
                    color: colorScheme.secondary,
                  ),
                  text: '分析统计',
                  onTap: logic.toAnalysePage),
              buildAFeatureButton(
                  icon: FaIcon(
                    FontAwesomeIcons.solidMap,
                    color: colorScheme.secondary,
                  ),
                  text: '足迹地图',
                  onTap: logic.toMap),
              buildAFeatureButton(
                  icon: FaIcon(
                    FontAwesomeIcons.solidCommentDots,
                    color: colorScheme.secondary,
                  ),
                  text: '智能助手',
                  onTap: logic.toAi),
            ],
          ),
        ],
      );
    }

    Widget buildData() {
      return Column(
        children: [
          SettingTitleTile(title: l10n.settingData),
          Card.filled(
            color: colorScheme.surfaceContainerLow,
            child: Column(
              children: [
                ListTile(
                  title: Text(l10n.settingRecycle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    logic.toRecyclePage();
                  },
                  leading: const Icon(Icons.delete_outline),
                ),
                ListTile(
                  title: const Text('备份与同步'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    logic.toBackupAndSyncPage();
                  },
                  leading: const Icon(Icons.sync),
                ),
                ListTile(
                  title: Text(l10n.settingClean),
                  leading: const Icon(Icons.cleaning_services_outlined),
                  trailing: GetBuilder<SettingLogic>(
                      id: 'DataUsage',
                      builder: (_) {
                        return Text(
                          state.dataUsage,
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
          )
        ],
      );
    }

    Widget buildDisplay() {
      return Column(
        children: [
          SettingTitleTile(title: l10n.settingDisplay),
          Card.filled(
            color: colorScheme.surfaceContainerLow,
            child: Column(
              children: [
                ListTile(
                  title: Text(l10n.settingDiary),
                  leading: const Icon(Icons.article_outlined),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    logic.toDiarySettingPage();
                  },
                ),
                ListTile(
                  title: Text(l10n.settingThemeMode),
                  leading: const Icon(Icons.invert_colors),
                  trailing: Text(
                    switch (state.themeMode) {
                      0 => l10n.themeModeSystem,
                      1 => l10n.themeModeLight,
                      2 => l10n.themeModeDark,
                      int() => throw UnimplementedError(),
                    },
                    style: textStyle.bodySmall!.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                  onTap: () {
                    showDialog(
                        context: context,
                        builder: (context) {
                          return const ThemeModeDialogComponent();
                        });
                  },
                ),
                ListTile(
                  title: Text(l10n.settingColor),
                  leading: const Icon(Icons.color_lens_outlined),
                  trailing: Text(
                    switch (state.color) {
                      0 => l10n.colorNameQunQin,
                      1 => l10n.colorNameJiHe,
                      2 => l10n.colorNameQinDai,
                      3 => l10n.colorNameXianYe,
                      4 => l10n.colorNameJinYu,
                      _ => l10n.colorNameSystem
                    },
                    style: textStyle.bodySmall!.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                  onTap: () {
                    showDialog(
                        context: context,
                        builder: (context) {
                          return const ColorDialogComponent();
                        });
                  },
                ),
                ListTile(
                  title: Text(l10n.settingFontSize),
                  leading: const Icon(Icons.format_size_outlined),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    logic.toFontSizePage();
                  },
                ),
                // ListTile(
                //   title: Text(l10n.settingFontStyle),
                //   leading: const Icon(Icons.text_format_outlined),
                //   trailing: Obx(() {
                //     return Text(
                //       switch (state.fontTheme.value) {
                //         0 => '思源黑体',
                //         1 => '思源宋体',
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
                //               title: Text(l10n.settingFontStyle),
                //               children: [
                //                 SimpleDialogOption(
                //                   child: Row(
                //                     children: [
                //                       const Text(
                //                         '思源黑体',
                //                         style:
                //                             TextStyle(fontFamily: 'NotoSans SC', fontFamilyFallback: ['NotoSans SC']),
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
                //                         style:
                //                             TextStyle(fontFamily: 'NotoSerif SC', fontFamilyFallback: ['NotoSerif SC']),
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
                ListTile(
                  title: const Text('自定义首页名称'),
                  leading: const Icon(Icons.drive_file_rename_outline),
                  trailing: GetBuilder<SettingLogic>(
                      id: 'CustomTitle',
                      builder: (_) {
                        return Text(
                          state.customTitle,
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
                                  child: Text(l10n.cancel)),
                              TextButton(
                                  onPressed: () async {
                                    await logic.setCustomTitle();
                                  },
                                  child: Text(l10n.ok))
                            ],
                          );
                        });
                  },
                )
              ],
            ),
          )
        ],
      );
    }

    Widget buildPrivacy() {
      return Column(
        children: [
          SettingTitleTile(title: l10n.settingPrivacy),
          Card.filled(
            color: colorScheme.surfaceContainerLow,
            child: Column(
              children: [
                GetBuilder<SettingLogic>(
                    id: 'Local',
                    builder: (_) {
                      return SwitchListTile(
                        value: state.local,
                        onChanged: null,
                        title: Text(l10n.settingLocal),
                        subtitle: Text(l10n.settingLocalDes),
                        secondary: const Icon(Icons.cloud_off_outlined),
                      );
                    }),
                GetBuilder<SettingLogic>(
                    id: 'Lock',
                    builder: (_) {
                      return ListTile(
                        trailing: Text(
                          state.lock ? l10n.settingLockOpen : l10n.settingLockNotOpen,
                          style: textStyle.bodySmall!.copyWith(
                            color: colorScheme.primary,
                          ),
                        ),
                        onTap: () {
                          showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: Text(l10n.settingLock),
                                  content:
                                      Text(state.lock ? l10n.settingLockResetLock : l10n.settingLockChooseLockType),
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
                                                return state.lock
                                                    ? const RemovePasswordComponent()
                                                    : const SetPasswordComponent();
                                              });
                                        },
                                        child: Text(state.lock ? '关闭' : '数字')),
                                  ],
                                );
                              });
                        },
                        title: Text(l10n.settingLock),
                        leading: const Icon(Icons.lock_outline),
                      );
                    }),
                GetBuilder<SettingLogic>(
                    id: 'Lock',
                    builder: (_) {
                      return SwitchListTile(
                        value: state.lockNow,
                        onChanged: state.lock
                            ? (value) {
                                logic.lockNow(value);
                              }
                            : null,
                        title: Text(l10n.settingLockNow),
                        subtitle: Text(l10n.settingLockNowDes),
                        secondary: const Icon(Icons.lock_clock_outlined),
                      );
                    }),
              ],
            ),
          )
        ],
      );
    }

    Widget buildMore() {
      return Column(
        children: [
          SettingTitleTile(title: l10n.settingMore),
          Card.filled(
            color: colorScheme.surfaceContainerLow,
            child: Column(
              children: [
                ListTile(
                  title: Text(l10n.settingAbout),
                  leading: const Icon(Icons.info_outline),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    logic.toAboutPage();
                  },
                ),
                ListTile(
                  title: Text(l10n.settingLab),
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
      );
    }

    return GetBuilder<SettingLogic>(
      assignId: true,
      builder: (_) {
        return CustomScrollView(
          slivers: [
            SliverAppBar(
              title: Text(l10n.homeNavigatorSetting),
              pinned: true,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4.0,
                  children: [
                    buildDashboard(),
                    buildFeature(),
                    buildData(),
                    buildDisplay(),
                    buildPrivacy(),
                    buildMore(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
