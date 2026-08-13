import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gap/gap.dart';
import 'package:moodiary/app/settings/presentation/widget/accent_sheet.dart';
import 'package:moodiary/app/settings/presentation/widget/cache_usage_tile.dart';
import 'package:moodiary/app/settings/presentation/widget/dashboard_section.dart';
import 'package:moodiary/app/settings/presentation/widget/data_repair_tile.dart';
import 'package:moodiary/app/settings/presentation/widget/language_dialog.dart';
import 'package:moodiary/app/settings/presentation/widget/reset_data_tile.dart';
import 'package:moodiary/app/settings/presentation/widget/theme_mode_dialog.dart';
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
        const DashboardSection(),
        const _DataSection(),
        const _DisplaySection(),
        const _PrivacySection(),
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
      appBar: AppBar(title: const Text('设置')),
      body: const _SettingSectionList(),
    );
  }
}

class _DataSection extends StatelessWidget {
  const _DataSection();

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        const SettingTitleTile(title: '数据'),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: .zero,
          child: Column(
            children: [
              SettingListTile(
                title: '回收站',
                isFirst: true,
                leading: Icon(
                  LucideIcons.trash,
                  color: scheme.onSurfaceVariant,
                ),
                trailing: Icon(
                  LucideIcons.chevronRight,
                  color: scheme.onSurfaceVariant,
                ),
                onTap: () => _openSetting(context, const RecycleRoute()),
              ),
              SettingListTile(
                title: '数据同步与备份',
                leading: Icon(
                  LucideIcons.refreshCw,
                  color: scheme.onSurfaceVariant,
                ),
                trailing: Icon(
                  LucideIcons.chevronRight,
                  color: scheme.onSurfaceVariant,
                ),
                onTap: () => _openSetting(context, const BackupSyncRoute()),
              ),
              SettingListTile(
                title: context.l10n.exportPageTitle,
                leading: Icon(
                  LucideIcons.fileOutput,
                  color: scheme.onSurfaceVariant,
                ),
                trailing: Icon(
                  LucideIcons.chevronRight,
                  color: scheme.onSurfaceVariant,
                ),
                onTap: () => _openSetting(context, const ExportRoute()),
              ),
              SettingListTile(
                title: '分类管理',
                leading: Icon(
                  LucideIcons.folders,
                  color: scheme.onSurfaceVariant,
                ),
                trailing: Icon(
                  LucideIcons.chevronRight,
                  color: scheme.onSurfaceVariant,
                ),
                onTap: () =>
                    _openSetting(context, const CategoryManagerRoute()),
              ),
              SettingListTile(
                title: '足迹地图',
                leading: Icon(LucideIcons.map, color: scheme.onSurfaceVariant),
                trailing: Icon(
                  LucideIcons.chevronRight,
                  color: scheme.onSurfaceVariant,
                ),
                onTap: () => _openSetting(context, const MapRoute()),
              ),
              SettingListTile(
                title: '迁移到新编辑器',
                subtitle: '把旧日记（富文本 / Markdown）转换为新编辑器以便编辑',
                leading: Icon(
                  LucideIcons.wandSparkles,
                  color: scheme.onSurfaceVariant,
                ),
                trailing: Icon(
                  LucideIcons.chevronRight,
                  color: scheme.onSurfaceVariant,
                ),
                onTap: () =>
                    _openSetting(context, const EditorMigrationRoute()),
              ),
              const DataRepairTile(),
              // 压测入口随图谱一起暂隐藏(StressTestTile,打磨期再放出)。
              const CacheUsageTile(),
              const ResetDataTile(isLast: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _DisplaySection extends ConsumerWidget {
  const _DisplaySection();

  static const _themeModeLabels = ['跟随系统', '浅色', '深色'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appSettingsControllerProvider);
    final scheme = context.theme.colors;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        const SettingTitleTile(title: '显示'),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: .zero,
          child: Column(
            children: [
              SettingListTile(
                title: '日记设置',
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
              ValueListenableBuilder(
                valueListenable: MoodiaryKVs.themeMode.getNotifier(),
                builder: (context, mode, _) {
                  return SettingListTile(
                    title: '主题模式',
                    leading: Icon(
                      LucideIcons.contrast,
                      color: scheme.onSurfaceVariant,
                    ),
                    trailing: Text(
                      _themeModeLabels[mode.clamp(
                        0,
                        _themeModeLabels.length - 1,
                      )],
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
                    title: context.l10n.accentTitle,
                    leading: Icon(
                      LucideIcons.palette,
                      color: scheme.onSurfaceVariant,
                    ),
                    trailing: Text(switch (mode) {
                      .neutral => context.l10n.accentNeutral,
                      .system => context.l10n.accentSystem,
                      .custom => context.l10n.accentCustom,
                    }, style: context.theme.typography.bodySmall.primary),
                    onTap: () => AccentSheet.show(context),
                  );
                },
              ),
              SettingListTile(
                isLast: true,
                title: '字体样式',
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
        const SettingTitleTile(title: '隐私'),
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
                    title: '后台隐私保护',
                    subtitle: '退到后台时遮罩内容',
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
        const SettingTitleTile(title: '更多'),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: .zero,
          child: Column(
            children: [
              SettingListTile(
                isFirst: true,
                title: '关于',
                leading: Icon(LucideIcons.info, color: scheme.onSurfaceVariant),
                trailing: Icon(
                  LucideIcons.chevronRight,
                  color: scheme.onSurfaceVariant,
                ),
                onTap: () => _openSetting(context, const AboutRoute()),
              ),
              SettingListTile(
                title: '语言',
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
                title: '第三方服务',
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
