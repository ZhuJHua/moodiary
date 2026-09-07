import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_mobile/app/settings/setting_routes.dart';
import 'package:moodiary_preferences/moodiary_preferences.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_theme/moodiary_theme.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

class AccentSheet extends ConsumerWidget {
  const AccentSheet({super.key});

  static Future<void> show(BuildContext context) {
    return MSheet.show<void>(context, builder: (_) => const AccentSheet());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modes = [
      ThemeAccentMode.neutral,
      if (getIt<ThemeManager>().supportDynamic) ThemeAccentMode.system,
      ThemeAccentMode.custom,
    ];

    return MSheetScaffold<void>(
      title: context.l10n.app.accentTitle,
      icon: LucideIcons.palette,
      child: ValueListenableBuilder<int>(
        valueListenable: MoodiaryKVs.themeAccentMode.getNotifier(),
        builder: (context, index, _) {
          final current = index >= 0 && index < ThemeAccentMode.values.length
              ? ThemeAccentMode.values[index]
              : ThemeAccentMode.neutral;
          return Column(
            crossAxisAlignment: .stretch,
            mainAxisSize: .min,
            children: [
              for (final mode in modes)
                _AccentModeRow(
                  mode: mode,
                  selected: mode == current,
                  onTap: () => _select(context, ref, mode),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    ThemeAccentMode mode,
  ) async {
    HapticFeedback.selectionClick();
    if (mode == .custom) {
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.pushRoute(const AccentRoute());
      return;
    }
    MoodiaryKVs.themeAccentMode.set(mode.index);
    await ref.read(appSettingsControllerProvider.notifier).bumpTheme();
  }
}

class _AccentModeRow extends StatelessWidget {
  final ThemeAccentMode mode;
  final bool selected;
  final VoidCallback onTap;

  const _AccentModeRow({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Semantics(
      selected: selected,
      child: Padding(
        padding: const .only(bottom: 6),
        child: Material(
          color: selected ? scheme.surfaceContainerLow : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: AppBorderRadius.mediumBorderRadius,
            side: BorderSide(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: MInkWell(
            borderRadius: AppBorderRadius.mediumBorderRadius,
            onTap: onTap,
            child: Padding(
              padding: const .symmetric(horizontal: 14, vertical: 12),
              child: Row(
                spacing: 12,
                children: [
                  SizedBox(width: 28, height: 28, child: _swatch(context)),
                  Expanded(
                    child: Text(
                      _label(context),
                      style: selected
                          ? context
                                .theme
                                .typography
                                .bodyLarge
                                .emphasized
                                .onSurface
                          : context.theme.typography.bodyLarge.onSurface,
                    ),
                  ),
                  if (selected)
                    Icon(LucideIcons.check, size: 18, color: scheme.primary)
                  else if (mode == .custom)
                    Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _label(BuildContext context) => switch (mode) {
    .neutral => context.l10n.app.accentNeutral,
    .system => context.l10n.app.accentSystem,
    .custom => context.l10n.common.custom,
  };

  Widget _swatch(BuildContext context) {
    final scheme = context.theme.colors;
    const radius = AppBorderRadius.smallBorderRadius;
    return switch (mode) {
      .neutral => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: scheme.outlineVariant),
          gradient: const LinearGradient(
            begin: .topLeft,
            end: .bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFF000000)],
          ),
        ),
      ),
      .system => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          color: getIt<ThemeManager>().systemAccentSeed ?? scheme.primary,
        ),
      ),
      .custom => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          color: Color(MoodiaryKVs.themeAccentColor.get()!),
        ),
      ),
    };
  }
}
