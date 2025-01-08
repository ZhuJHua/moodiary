import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mood_diary/common/values/border.dart';
import 'package:mood_diary/common/values/colors.dart';
import 'package:mood_diary/components/base/sheet.dart';
import 'package:mood_diary/components/color_sheet/color_sheet_view.dart';
import 'package:mood_diary/components/dashboard/dashboard_view.dart';
import 'package:mood_diary/components/remove_password/remove_password_view.dart';
import 'package:mood_diary/components/set_password/set_password_view.dart';
import 'package:mood_diary/components/theme_mode_dialog/theme_mode_dialog_view.dart';
import 'package:mood_diary/components/tile/setting_tile.dart';
import 'package:refreshed/refreshed.dart';

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

    Widget buildAFeatureButton(
        {required Widget icon,
        required String text,
        required Function() onTap}) {
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
                style: textStyle.labelSmall?.copyWith(
                  color: colorScheme.onSurface,
                ),
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
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 100, childAspectRatio: 1.0),
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
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12.0),
                      topRight: Radius.circular(12.0),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    logic.toRecyclePage();
                  },
                  leading: const Icon(Icons.delete_rounded),
                ),
                ListTile(
                  title: const Text('备份与同步'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    logic.toBackupAndSyncPage();
                  },
                  leading: const Icon(Icons.sync_rounded),
                ),
                ListTile(
                  title: Text(l10n.settingClean),
                  leading: const Icon(Icons.cleaning_services_rounded),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12.0),
                      bottomRight: Radius.circular(12.0),
                    ),
                  ),
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
                  leading: const Icon(Icons.article_rounded),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12.0),
                      topRight: Radius.circular(12.0),
                    ),
                  ),
                  onTap: () {
                    logic.toDiarySettingPage();
                  },
                ),
                ListTile(
                  title: Text(l10n.settingThemeMode),
                  leading: const Icon(Icons.invert_colors_rounded),
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
                  leading: const Icon(Icons.color_lens_rounded),
                  trailing: Text(
                    AppColor.colorName(state.color),
                    style: textStyle.bodySmall!.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                  onTap: () {
                    showFloatingModalBottomSheet(
                        context: context,
                        builder: (context) {
                          return const ColorSheetComponent();
                        });
                  },
                ),
                ListTile(
                  title: Text(l10n.settingFontStyle),
                  leading: const Icon(Icons.format_size_rounded),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    logic.toFontSizePage();
                  },
                ),
                ListTile(
                  title: const Text('首页名称'),
                  leading: const Icon(Icons.drive_file_rename_outline_rounded),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12.0),
                      bottomRight: Radius.circular(12.0),
                    ),
                  ),
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
                  onTap: () async {
                    var res = await showTextInputDialog(
                      context: context,
                      textFields: [
                        DialogTextField(
                          hintText: '名称',
                          initialText: state.customTitle,
                        )
                      ],
                      title: '首页名称',
                    );
                    if (res != null) {
                      logic.setCustomTitle(title: res.first);
                    }
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
                // GetBuilder<SettingLogic>(
                //     id: 'Local',
                //     builder: (_) {
                //       return SwitchListTile(
                //         value: state.local,
                //         onChanged: null,
                //         title: Text(l10n.settingLocal),
                //         subtitle: Text(l10n.settingLocalDes),
                //         secondary: const Icon(Icons.cloud_off_rounded),
                //       );
                //     }),
                GetBuilder<SettingLogic>(
                    id: 'Lock',
                    builder: (_) {
                      return ListTile(
                        trailing: Text(
                          state.lock
                              ? l10n.settingLockOpen
                              : l10n.settingLockNotOpen,
                          style: textStyle.bodySmall!.copyWith(
                            color: colorScheme.primary,
                          ),
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12.0),
                            topRight: Radius.circular(12.0),
                          ),
                        ),
                        onTap: () async {
                          var res = await showOkCancelAlertDialog(
                              context: context,
                              title: l10n.settingLock,
                              message: state.lock
                                  ? l10n.settingLockResetLock
                                  : l10n.settingLockChooseLockType,
                              okLabel: state.lock ? '关闭密码' : '数字');
                          if (res == OkCancelResult.ok && context.mounted) {
                            showFloatingModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (context) {
                                  return state.lock
                                      ? const RemovePasswordComponent()
                                      : const SetPasswordComponent();
                                });
                          }
                        },
                        title: Text(l10n.settingLock),
                        leading: const Icon(Icons.lock_rounded),
                      );
                    }),
                GetBuilder<SettingLogic>(
                    id: 'Lock',
                    builder: (_) {
                      return SwitchListTile(
                        value: state.lockNow,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(12.0),
                            bottomRight: Radius.circular(12.0),
                          ),
                        ),
                        onChanged: state.lock
                            ? (value) {
                                logic.lockNow(value);
                              }
                            : null,
                        title: Text(l10n.settingLockNow),
                        subtitle: Text(l10n.settingLockNowDes),
                        secondary: const Icon(Icons.lock_clock_rounded),
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
                  leading: const Icon(Icons.info_rounded),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12.0),
                      topRight: Radius.circular(12.0),
                    ),
                  ),
                  onTap: () {
                    logic.toAboutPage();
                  },
                ),
                ListTile(
                  title: Text(l10n.settingLab),
                  leading: const Icon(Icons.science_rounded),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12.0),
                      bottomRight: Radius.circular(12.0),
                    ),
                  ),
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
        return Column(
          children: [
            AppBar(
              title: Text(l10n.homeNavigatorSetting),
              centerTitle: false,
            ),
            Expanded(
              child: ListView(
                cacheExtent: size.height * 2,
                padding: const EdgeInsets.all(4.0),
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
          ],
        );
      },
    );
  }
}
