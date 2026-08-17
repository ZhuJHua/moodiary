import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gap/gap.dart';
import 'package:moodiary/app/settings/presentation/widget/accent_sheet.dart';
import 'package:moodiary/app/settings/presentation/widget/cache_usage_tile.dart';
import 'package:moodiary/app/settings/presentation/widget/data_repair_tile.dart';
import 'package:moodiary/app/settings/presentation/widget/language_dialog.dart';
import 'package:moodiary/app/settings/presentation/widget/reset_data_tile.dart';
import 'package:moodiary/app/settings/presentation/widget/theme_mode_dialog.dart';
import 'package:moodiary_assistant/moodiary_assistant.dart'
    show AssistantSettingRoute;
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_lock/moodiary_lock.dart';
import 'package:moodiary_preferences/moodiary_preferences.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:mui/mui.dart';

/// 一级菜单项跳转：全屏 `push` 落 root navigator。
void _openSetting(BuildContext context, MoodiaryRouteBase route) {
  route.push(context);
}

class _SettingSectionList extends StatelessWidget {
  const _SettingSectionList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      // 本页从底栏 tab 变成了 push 出来的整页路由：以前 Scaffold 因为有
      // bottomNavigationBar 会把 body 的 padding.bottom 清零、导航条自己占住安全区，
      // 现在没人吃这个 inset 了 —— 不补的话最后一行会压在手势条 / 三键导航底下。
      padding: .fromLTRB(8, 8, 8, 8 + MediaQuery.paddingOf(context).bottom),
      children: [
        const _FeatureSection(),
        const _DisplaySection(),
        const _PrivacySection(),
        const _DataSection(),
        const _MoreSection(),
      ].intersperse(const Gap(4.0)).toList(),
    );
  }
}

/// 移动端设置子页是 [StatefulShellRoute] 的顶层兄弟（push 落 root navigator 全屏
/// 盖过 shell），故本页只渲染 `/setting` 列表。
class SettingListPageMobile extends StatelessWidget {
  const SettingListPageMobile({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.app.settingsTitle)),
      body: const _SettingSectionList(),
    );
  }
}

/// 功能开关式的子页。「日记设置」与「智能助手」是同一类东西 —— 某个功能自己的偏好，
/// 平级摆在一起。
class _FeatureSection extends StatelessWidget {
  const _FeatureSection();

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        SettingTitleTile(title: context.l10n.app.sectionFeature),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: .zero,
          child: Column(
            children: [
              SettingListTile(
                title: context.l10n.app.diarySettings,
                isFirst: true,
                leading: Icon(
                  LucideIcons.fileText,
                  color: scheme.onSurfaceVariant,
                ),
                trailing: Icon(
                  LucideIcons.chevronRight,
                  color: scheme.onSurfaceVariant,
                ),
                onTap: () => _openSetting(context, const DiarySettingRoute()),
              ),
              SettingListTile(
                isLast: true,
                title: context.l10n.app.assistantEntry,
                leading: Icon(LucideIcons.bot, color: scheme.onSurfaceVariant),
                trailing: Icon(
                  LucideIcons.chevronRight,
                  color: scheme.onSurfaceVariant,
                ),
                onTap: () =>
                    _openSetting(context, const AssistantSettingRoute()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 只剩维护动作 —— 回收站 / 分类管理 / 导出 / 同步、以及足迹地图都归「我的」了，
/// 那些操作的是内容，不是偏好。
class _DataSection extends StatelessWidget {
  const _DataSection();

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        SettingTitleTile(title: context.l10n.app.sectionData),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: .zero,
          child: const Column(
            children: [
              DataRepairTile(isFirst: true),
              // 压测入口随图谱一起暂隐藏(StressTestTile,打磨期再放出)。
              CacheUsageTile(),
              ResetDataTile(isLast: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _DisplaySection extends ConsumerWidget {
  const _DisplaySection();

  static List<String> _themeModeLabels(Translations l10n) => [
    l10n.app.themeModeSystem,
    l10n.app.themeModeLight,
    l10n.app.themeModeDark,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appSettingsControllerProvider);
    final scheme = context.theme.colors;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        SettingTitleTile(title: context.l10n.app.sectionDisplay),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: .zero,
          child: Column(
            children: [
              ValueListenableBuilder(
                valueListenable: MoodiaryKVs.themeMode.getNotifier(),
                builder: (context, mode, _) {
                  return SettingListTile(
                    isFirst: true,
                    title: context.l10n.app.themeMode,
                    leading: Icon(
                      LucideIcons.contrast,
                      color: scheme.onSurfaceVariant,
                    ),
                    trailing: Text(
                      _themeModeLabels(context.l10n)[mode.clamp(0, 2)],
                      style: context.theme.typography.bodySmall.primary,
                    ),
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => const ThemeModeDialog(),
                    ),
                  );
                },
              ),
              ValueListenableBuilder(
                valueListenable: MoodiaryKVs.themeAccentMode.getNotifier(),
                builder: (context, index, _) {
                  final mode =
                      index >= 0 && index < ThemeAccentMode.values.length
                      ? ThemeAccentMode.values[index]
                      : ThemeAccentMode.neutral;
                  return SettingListTile(
                    title: context.l10n.app.accentTitle,
                    leading: Icon(
                      LucideIcons.palette,
                      color: scheme.onSurfaceVariant,
                    ),
                    trailing: Text(switch (mode) {
                      .neutral => context.l10n.app.accentNeutral,
                      .system => context.l10n.app.accentSystem,
                      .custom => context.l10n.common.custom,
                    }, style: context.theme.typography.bodySmall.primary),
                    onTap: () => AccentSheet.show(context),
                  );
                },
              ),
              SettingListTile(
                isLast: true,
                title: context.l10n.app.fontStyle,
                leading: Icon(LucideIcons.type, color: scheme.onSurfaceVariant),
                trailing: Icon(
                  LucideIcons.chevronRight,
                  color: scheme.onSurfaceVariant,
                ),
                onTap: () => _openSetting(context, const FontRoute()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection();

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        SettingTitleTile(title: context.l10n.app.sectionPrivacy),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: .zero,
          child: Column(
            children: [
              const AppLockTile(),
              ValueListenableBuilder(
                valueListenable: MoodiaryKVs.backendPrivacy.getNotifier(),
                builder: (context, on, _) {
                  return SettingSwitchListTile(
                    isLast: true,
                    title: context.l10n.app.backgroundPrivacy,
                    subtitle: context.l10n.app.backgroundPrivacySubtitle,
                    secondary: Icon(
                      LucideIcons.eyeOff,
                      color: scheme.onSurfaceVariant,
                    ),
                    value: on,
                    onChanged: (v) => MoodiaryKVs.backendPrivacy.set(v),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MoreSection extends ConsumerWidget {
  const _MoreSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appSettingsControllerProvider);
    final scheme = context.theme.colors;
    final langCode = MoodiaryKVs.language.get() ?? Language.system.languageCode;
    final lang = Language.values.firstWhere(
      (e) => e.languageCode == langCode,
      orElse: () => Language.system,
    );
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        SettingTitleTile(title: context.l10n.app.sectionMore),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: .zero,
          child: Column(
            children: [
              SettingListTile(
                isFirst: true,
                title: context.l10n.app.about,
                leading: Icon(LucideIcons.info, color: scheme.onSurfaceVariant),
                trailing: Icon(
                  LucideIcons.chevronRight,
                  color: scheme.onSurfaceVariant,
                ),
                onTap: () => _openSetting(context, const AboutRoute()),
              ),
              SettingListTile(
                title: context.l10n.app.language,
                leading: Icon(
                  LucideIcons.languages,
                  color: scheme.onSurfaceVariant,
                ),
                trailing: Text(
                  lang.l10nText(context),
                  style: context.theme.typography.bodySmall.primary,
                ),
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => const LanguageDialog(),
                ),
              ),
              SettingListTile(
                isLast: true,
                title: context.l10n.app.services,
                leading: Icon(
                  LucideIcons.waypoints,
                  color: scheme.onSurfaceVariant,
                ),
                trailing: Icon(
                  LucideIcons.chevronRight,
                  color: scheme.onSurfaceVariant,
                ),
                onTap: () => _openSetting(context, const ServicesRoute()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
