import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_mobile/app/settings/presentation/widget/mood_palette_sheet.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';

void main() {
  setUpAll(setupPluralResolvers);
  setUp(() => getIt.registerSingleton<IKVStorage>(MemoryKVStorage()));
  tearDown(getIt.reset);

  for (final brightness in Brightness.values) {
    testWidgets(
      '$brightness settings previews harmonize each option with the accent',
      (tester) async {
        final accent = ValueNotifier(const MuiAccent.seeded(Color(0xFF2E59A7)));
        addTearDown(accent.dispose);
        MoodiaryKVs.moodPalette.set(MoodPalette.blueOrange.name);
        await tester.pumpWidget(
          ProviderScope(
            child: TranslationProvider(
              child: ValueListenableBuilder<MuiAccent>(
                valueListenable: accent,
                builder: (context, value, _) => MaterialApp(
                  theme: buildMuiTheme(brightness: brightness, accent: value),
                  locale: const Locale('zh'),
                  supportedLocales: AppLocaleUtils.supportedLocales,
                  localizationsDelegates: const [
                    ...GlobalMaterialLocalizations.delegates,
                    GlobalMuiLocalizations.delegate,
                  ],
                  home: const Scaffold(body: MoodPaletteSheet()),
                ),
              ),
            ),
          ),
        );
        for (final value in [
          const MuiAccent.seeded(Color(0xFF2E59A7)),
          const MuiAccent.seeded(Color(0xFF00897B)),
          const MuiAccent.neutral(),
        ]) {
          accent.value = value;
          await tester.pumpAndSettle();
          final colors = buildMuiTheme(
            brightness: brightness,
            accent: value,
          ).colorScheme;
          expect(find.byType(MoodGlyph), findsNWidgets(10));
          for (final palette in MoodPalette.values) {
            for (final mood in DiaryMood.values) {
              final glyph = find.byWidgetPredicate(
                (widget) =>
                    widget is MoodGlyph &&
                    widget.palette == palette &&
                    widget.mood == mood,
              );
              expect(glyph, paints..circle(color: palette.color(mood, colors)));
            }
          }
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
