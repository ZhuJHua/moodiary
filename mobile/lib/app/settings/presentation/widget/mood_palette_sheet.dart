import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_preferences/moodiary_preferences.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

class MoodPaletteSheet extends ConsumerWidget {
  const MoodPaletteSheet({super.key});

  static Future<void> show(BuildContext context) =>
      MSheet.show<void>(context, builder: (_) => const MoodPaletteSheet());

  @override
  Widget build(BuildContext context, WidgetRef ref) => MSheetScaffold<void>(
    title: context.l10n.app.moodColors,
    icon: LucideIcons.smile,
    child: ValueListenableBuilder<String>(
      valueListenable: MoodiaryKVs.moodPalette.getNotifier(),
      builder: (context, value, _) => Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          for (final palette in MoodPalette.values)
            MSheetOptionTile<MoodPalette>(
              option: MSheetOption(
                value: palette,
                label: palette.label(context),
                subtitle: switch (palette) {
                  .classic => context.l10n.app.moodPaletteDefault,
                  .blueOrange => context.l10n.app.moodPaletteColorblind,
                },
                leading: Row(
                  mainAxisSize: .min,
                  spacing: 3,
                  children: [
                    for (final mood in DiaryMood.values)
                      MoodGlyph(mood: mood, size: 18, palette: palette),
                  ],
                ),
              ),
              selected: palette == MoodPalette.fromName(value),
              onTap: () async {
                HapticFeedback.selectionClick();
                MoodiaryKVs.moodPalette.set(palette.name);
                await ref
                    .read(appSettingsControllerProvider.notifier)
                    .bumpTheme();
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
        ],
      ),
    ),
  );
}
