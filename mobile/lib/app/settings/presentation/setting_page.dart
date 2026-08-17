import 'package:flutter_riverpod/flutter_riverpod.dart';
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

Widget _lead(BuildContext context, IconData icon) =>
    Icon(icon, color: context.theme.colors.onSurfaceVariant);

Widget _chevron(BuildContext context) => Icon(
  LucideIcons.chevronRight,
  color: context.theme.colors.onSurfaceVariant,
);

Widget _value(BuildContext context, String text) =>
    Text(text, style: context.theme.typography.bodySmall.primary);

/// 组与组之间的间隔。
const _gap = SliverToBoxAdapter(child: SizedBox(height: 4));

/// 移动端设置子页是顶层兄弟路由（push 落 root navigator 全屏盖过 shell），故本页只
/// 渲染 `/setting` 列表。
class SettingListPageMobile extends StatelessWidget {
  const SettingListPageMobile({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.app.settingsTitle)),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            // 本页是 push 出来的整页路由，没有 bottomNavigationBar 去吃掉底部 inset，
            // 不补的话最后一行会压在手势条 / 三键导航底下。
            padding: .fromLTRB(
              8,
              8,
              8,
              8 + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: const SliverMainAxisGroup(
              slivers: [
                _FeatureSection(),
                _gap,
                _DisplaySection(),
                _gap,
                _PrivacySection(),
                _gap,
                _DataSection(),
                _gap,
                _MoreSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 功能开关式的子页。「日记设置」与「智能助手」是同一类东西 —— 某个功能自己的偏好，
/// 平级摆在一起。
class _FeatureSection extends StatelessWidget {
  const _FeatureSection();

  @override
  Widget build(BuildContext context) {
    return MSliverSettingGroup(
      title: context.l10n.app.sectionFeature,
      children: [
        SettingListTile(
          title: context.l10n.app.diarySettings,
          leading: _lead(context, LucideIcons.fileText),
          trailing: _chevron(context),
          onTap: () => _openSetting(context, const DiarySettingRoute()),
        ),
        SettingListTile(
          title: context.l10n.app.assistantEntry,
          leading: _lead(context, LucideIcons.bot),
          trailing: _chevron(context),
          onTap: () => _openSetting(context, const AssistantSettingRoute()),
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
    return MSliverSettingGroup(
      title: context.l10n.app.sectionDisplay,
      children: [
        ValueListenableBuilder(
          valueListenable: MoodiaryKVs.themeMode.getNotifier(),
          builder: (context, mode, _) {
            return SettingListTile(
              title: context.l10n.app.themeMode,
              leading: _lead(context, LucideIcons.contrast),
              trailing: _value(
                context,
                _themeModeLabels(context.l10n)[mode.clamp(0, 2)],
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
            final mode = index >= 0 && index < ThemeAccentMode.values.length
                ? ThemeAccentMode.values[index]
                : ThemeAccentMode.neutral;
            return SettingListTile(
              title: context.l10n.app.accentTitle,
              leading: _lead(context, LucideIcons.palette),
              trailing: _value(context, switch (mode) {
                .neutral => context.l10n.app.accentNeutral,
                .system => context.l10n.app.accentSystem,
                .custom => context.l10n.common.custom,
              }),
              onTap: () => AccentSheet.show(context),
            );
          },
        ),
        SettingListTile(
          title: context.l10n.app.fontStyle,
          leading: _lead(context, LucideIcons.type),
          trailing: _chevron(context),
          onTap: () => _openSetting(context, const FontRoute()),
        ),
      ],
    );
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection();

  @override
  Widget build(BuildContext context) {
    return MSliverSettingGroup(
      title: context.l10n.app.sectionPrivacy,
      children: [
        // 自己就是一组多行（开关 / 改密码 / 立即上锁 / 生物识别），行数还随状态变，
        // 所以它自带内部分隔线，在本组里算一项。
        const AppLockTile(),
        ValueListenableBuilder(
          valueListenable: MoodiaryKVs.backendPrivacy.getNotifier(),
          builder: (context, on, _) {
            return SettingSwitchListTile(
              title: context.l10n.app.backgroundPrivacy,
              subtitle: context.l10n.app.backgroundPrivacySubtitle,
              secondary: _lead(context, LucideIcons.eyeOff),
              value: on,
              onChanged: (v) => MoodiaryKVs.backendPrivacy.set(v),
            );
          },
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
    return MSliverSettingGroup(
      title: context.l10n.app.sectionData,
      children: const [
        DataRepairTile(),
        // 压测入口随图谱一起暂隐藏(StressTestTile,打磨期再放出)。
        CacheUsageTile(),
        ResetDataTile(),
      ],
    );
  }
}

class _MoreSection extends ConsumerWidget {
  const _MoreSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appSettingsControllerProvider);
    final langCode = MoodiaryKVs.language.get() ?? Language.system.languageCode;
    final lang = Language.values.firstWhere(
      (e) => e.languageCode == langCode,
      orElse: () => Language.system,
    );
    return MSliverSettingGroup(
      title: context.l10n.app.sectionMore,
      children: [
        SettingListTile(
          title: context.l10n.app.about,
          leading: _lead(context, LucideIcons.info),
          trailing: _chevron(context),
          onTap: () => _openSetting(context, const AboutRoute()),
        ),
        SettingListTile(
          title: context.l10n.app.language,
          leading: _lead(context, LucideIcons.languages),
          trailing: _value(context, lang.l10nText(context)),
          onTap: () => showDialog(
            context: context,
            builder: (_) => const LanguageDialog(),
          ),
        ),
        SettingListTile(
          title: context.l10n.app.services,
          leading: _lead(context, LucideIcons.waypoints),
          trailing: _chevron(context),
          onTap: () => _openSetting(context, const ServicesRoute()),
        ),
      ],
    );
  }
}
