import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:moodiary/common/values/border.dart';
import 'package:moodiary/common/values/colors.dart';
import 'package:moodiary/common/values/language.dart';
import 'package:moodiary/components/base/sheet.dart';
import 'package:moodiary/components/base/text.dart';
import 'package:moodiary/components/color_sheet/color_sheet_view.dart';
import 'package:moodiary/components/dashboard/dashboard_view.dart';
import 'package:moodiary/components/language_dialog/language_dialog_view.dart';
import 'package:moodiary/components/remove_password/remove_password_view.dart';
import 'package:moodiary/components/set_password/set_password_view.dart';
import 'package:moodiary/components/theme_mode_dialog/theme_mode_dialog_view.dart';
import 'package:moodiary/components/tile/setting_tile.dart';
import 'package:moodiary/main.dart';
import 'package:refreshed/refreshed.dart';

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
      return Column(
        children: [
          AdaptiveTitleTile(title: l10n.settingDashboard),
          const DashboardComponent(),
        ],
      );
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
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                icon,
                buildAdaptiveText(
                  text: text,
                  textStyle: textStyle.labelSmall
                      ?.copyWith(color: colorScheme.secondary),
                  context: context,
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget buildFeature() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdaptiveTitleTile(title: l10n.settingFunction),
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
                  text: l10n.settingFunctionCategoryManage,
                  onTap: logic.toCategoryManager),
              buildAFeatureButton(
                  icon: FaIcon(
                    FontAwesomeIcons.squarePollVertical,
                    color: colorScheme.secondary,
                  ),
                  text: l10n.settingFunctionAnalysis,
                  onTap: logic.toAnalysePage),
              buildAFeatureButton(
                  icon: FaIcon(
                    FontAwesomeIcons.solidMap,
                    color: colorScheme.secondary,
                  ),
                  text: l10n.settingFunctionTrailMap,
                  onTap: logic.toMap),
              buildAFeatureButton(
                  icon: FaIcon(
                    FontAwesomeIcons.solidCommentDots,
                    color: colorScheme.secondary,
                  ),
                  text: l10n.settingFunctionAIAssistant,
                  onTap: logic.toAi),
            ],
          ),
        ],
      );
    }

    Widget buildData() {
      return Column(
        children: [
          AdaptiveTitleTile(title: l10n.settingData),
          Card.filled(
            color: colorScheme.surfaceContainerLow,
            child: Column(
              children: [
                AdaptiveListTile(
                  title: Text(l10n.settingRecycle),
                  isFirst: true,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    logic.toRecyclePage();
                  },
                  leading: const Icon(Icons.delete_rounded),
                ),
                AdaptiveListTile(
                  title: Text(l10n.settingDataSyncAndBackup),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    logic.toBackupAndSyncPage();
                  },
                  leading: const Icon(Icons.sync_rounded),
                ),
                AdaptiveListTile(
                  title: Text(l10n.settingClean),
                  leading: const Icon(Icons.cleaning_services_rounded),
                  isLast: true,
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
          AdaptiveTitleTile(title: l10n.settingDisplay),
          Card.filled(
            color: colorScheme.surfaceContainerLow,
            child: Column(
              children: [
                AdaptiveListTile(
                  title: Text(l10n.settingDiary),
                  leading: const Icon(Icons.article_rounded),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  isFirst: true,
                  onTap: () {
                    logic.toDiarySettingPage();
                  },
                ),
                AdaptiveListTile(
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
                AdaptiveListTile(
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
                AdaptiveListTile(
                  title: Text(l10n.settingFontStyle),
                  leading: const Icon(Icons.format_size_rounded),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    logic.toFontSizePage();
                  },
                ),
                AdaptiveListTile(
                  title: Text(l10n.settingHomepageName),
                  leading: const Icon(Icons.drive_file_rename_outline_rounded),
                  isLast: true,
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
                          initialText: state.customTitle,
                        )
                      ],
                      title: l10n.settingHomepageName,
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
          AdaptiveTitleTile(title: l10n.settingPrivacy),
          Card.filled(
            color: colorScheme.surfaceContainerLow,
            child: Column(
              children: [
                // GetBuilder<SettingLogic>(
                //     id: 'Local',
                //     builder: (_) {
                //       return AdaptiveSwitchListTile(
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
                      return AdaptiveListTile(
                        trailing: Text(
                          state.lock
                              ? l10n.settingLockOpen
                              : l10n.settingLockNotOpen,
                          style: textStyle.bodySmall!.copyWith(
                            color: colorScheme.primary,
                          ),
                        ),
                        isFirst: true,
                        onTap: () async {
                          var res = await showOkCancelAlertDialog(
                            context: context,
                            title: l10n.settingLock,
                            message: state.lock
                                ? l10n.settingLockResetLock
                                : l10n.settingLockChooseLockType,
                            okLabel: state.lock
                                ? l10n.settingLockClose
                                : l10n.settingLockTypeNumber,
                          );
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
                      return AdaptiveSwitchListTile(
                        value: state.lockNow,
                        onChanged: state.lock
                            ? (value) {
                                logic.lockNow(value);
                              }
                            : null,
                        title: Text(l10n.settingLockNow),
                        subtitle: l10n.settingLockNowDes,
                        secondary: const Icon(Icons.lock_clock_rounded),
                      );
                    }),
                Obx(() {
                  return AdaptiveSwitchListTile(
                    value: state.backendPrivacy.value,
                    onChanged: logic.changeBackendPrivacy,
                    title: l10n.settingBackendPrivacyProtection,
                    subtitle: l10n.settingBackendPrivacyProtectionDes,
                    secondary: const Icon(Icons.remove_red_eye_rounded),
                    isLast: true,
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
          AdaptiveTitleTile(title: l10n.settingMore),
          Card.filled(
            color: colorScheme.surfaceContainerLow,
            child: Column(
              children: [
                AdaptiveListTile(
                  title: Text(l10n.settingAbout),
                  leading: const Icon(Icons.info_rounded),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  isFirst: true,
                  onTap: () {
                    logic.toAboutPage();
                  },
                ),
                AdaptiveListTile(
                  title: Text(l10n.settingLanguage),
                  leading: const Icon(Icons.language_rounded),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return const LanguageDialogComponent();
                      },
                    );
                  },
                  trailing: Obx(() {
                    return Text(
                      state.language.value.l10nText,
                      style: textStyle.bodySmall!.copyWith(
                        color: colorScheme.primary,
                      ),
                    );
                  }),
                ),
                AdaptiveListTile(
                  title: Text(l10n.settingLab),
                  leading: const Icon(Icons.science_rounded),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  isLast: true,
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
        return SafeArea(
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
        );
      },
    );
  }
}
