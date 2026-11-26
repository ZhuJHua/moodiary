import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_lock/moodiary_lock.dart';
import 'package:moodiary_mcp/moodiary_mcp.dart';
import 'package:moodiary_mobile/app/settings/presentation/widget/accent_sheet.dart';
import 'package:moodiary_mobile/app/settings/presentation/widget/data_repair_tile.dart';
import 'package:moodiary_mobile/app/settings/presentation/widget/image_optimize_tile.dart';
import 'package:moodiary_mobile/app/settings/presentation/widget/language_dialog.dart';
import 'package:moodiary_mobile/app/settings/presentation/widget/mood_palette_sheet.dart';
import 'package:moodiary_mobile/app/settings/presentation/widget/theme_mode_dialog.dart';
import 'package:moodiary_mobile/app/settings/setting_routes.dart';
import 'package:moodiary_preferences/moodiary_preferences.dart';
import 'package:moodiary_reminder/moodiary_reminder.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_theme/moodiary_theme.dart';

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

class SettingPage extends StatelessWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.app.settingsTitle)),
      body: Padding(
        padding: const .symmetric(horizontal: 8.0),
        child: CustomScrollView(
          slivers: [
            const _FeatureSection(),
            const _DisplaySection(),
            const _PrivacySection(),
            const _DataSection(),
            const _MoreSection(),
            SliverGap(context.safeBottom),
          ],
        ),
      ),
    );
  }
}

class _FeatureSection extends ConsumerWidget {
  const _FeatureSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminder = ref.watch(reminderStateProvider);
    final enabled = ref.watch(kvValueProvider(MoodiaryKVs.assistantEnabled));
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
          subtitle: enabled ? null : context.l10n.app.assistantStatusOff,
          leading: _lead(context, LucideIcons.bot),
          trailing: _chevron(context),
          onTap: () => _openSetting(context, const AssistantSettingRoute()),
        ),
        if (Platform.isAndroid) const _McpTile(),
        SettingListTile(
          title: context.l10n.reminder.title,
          subtitle: reminderStatusLabel(context.l10n, reminder),
          leading: _lead(context, LucideIcons.bell),
          trailing: _chevron(context),
          onTap: () => _openSetting(context, const ReminderRoute()),
        ),
      ],
    );
  }
}

class _McpTile extends ConsumerWidget {
  const _McpTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(kvValueProvider(MoodiaryKVs.mcpEnabled));
    final state = ref.watch(mcpServerStateProvider);
    return SettingListTile(
      title: context.l10n.app.mcpPageTitle,
      subtitle: _summary(context, state, enabled: enabled),
      leading: _lead(context, LucideIcons.server),
      trailing: _chevron(context),
      onTap: () => _openSetting(context, const McpRoute()),
    );
  }

  String _summary(
    BuildContext context,
    McpServerState state, {
    required bool enabled,
  }) {
    final l10n = context.l10n.app;
    if (!enabled) return l10n.mcpStatusStopped;
    return switch (state.status) {
      .running =>
        state.endpoints.firstOrNull?.toString() ?? l10n.mcpStatusRunning,
      .starting => l10n.mcpStatusStarting,
      .failed => l10n.mcpStatusFailedTitle,
      .stopped => l10n.mcpStatusStopped,
    };
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
    final mode = ref.watch(appSettingsControllerProvider).themeMode.index;
    final index = ref.watch(kvValueProvider(MoodiaryKVs.themeAccentMode));
    final accent = index >= 0 && index < ThemeAccentMode.values.length
        ? ThemeAccentMode.values[index]
        : ThemeAccentMode.neutral;
    final palette = ref.watch(kvValueProvider(MoodiaryKVs.moodPalette));
    return MSliverSettingGroup(
      title: context.l10n.app.sectionDisplay,
      children: [
        SettingListTile(
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
        ),
        SettingListTile(
          title: context.l10n.app.accentTitle,
          leading: _lead(context, LucideIcons.palette),
          trailing: _value(context, switch (accent) {
            .neutral => context.l10n.app.accentNeutral,
            .system => context.l10n.app.accentSystem,
            .custom => context.l10n.common.custom,
          }),
          onTap: () => AccentSheet.show(context),
        ),
        SettingListTile(
          title: context.l10n.app.fontStyle,
          leading: _lead(context, LucideIcons.type),
          trailing: _chevron(context),
          onTap: () => _openSetting(context, const FontRoute()),
        ),
        SettingListTile(
          title: context.l10n.app.moodColors,
          leading: _lead(context, LucideIcons.smile),
          trailing: _value(
            context,
            MoodPalette.fromName(palette).label(context),
          ),
          onTap: () => MoodPaletteSheet.show(context),
        ),
      ],
    );
  }
}

class _PrivacySection extends ConsumerWidget {
  const _PrivacySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MSliverSettingGroup(
      title: context.l10n.app.sectionPrivacy,
      children: [
        const AppLockTile(),
        SettingSwitchListTile(
          title: context.l10n.app.backgroundPrivacy,
          subtitle: context.l10n.app.backgroundPrivacySubtitle,
          secondary: _lead(context, LucideIcons.eyeOff),
          value: ref.watch(kvValueProvider(MoodiaryKVs.backendPrivacy)),
          onChanged: (v) => MoodiaryKVs.backendPrivacy.set(v),
        ),
      ],
    );
  }
}

class _DataSection extends StatelessWidget {
  const _DataSection();

  @override
  Widget build(BuildContext context) {
    return MSliverSettingGroup(
      title: context.l10n.app.sectionData,
      children: [
        const DataRepairTile(),
        const ImageOptimizeTile(),
        SettingListTile(
          title: context.l10n.storage.title,
          leading: _lead(context, LucideIcons.hardDrive),
          trailing: _chevron(context),
          onTap: () => _openSetting(context, const StorageRoute()),
        ),
      ],
    );
  }
}

class _MoreSection extends ConsumerWidget {
  const _MoreSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final langCode = ref.watch(kvValueProvider(MoodiaryKVs.language));
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
          trailing: _value(context, lang.label(context)),
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
