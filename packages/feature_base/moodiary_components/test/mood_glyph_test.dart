import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';

import 'support/pump.dart';

void main() {
  setUp(() => getIt.registerSingleton<IKVStorage>(MemoryKVStorage()));
  tearDown(getIt.reset);

  test('palette storage defaults and round-trips stable names', () {
    expect(MoodiaryKVs.moodPalette.get(), 'classic');
    expect(MoodPalette.current, MoodPalette.classic);
    MoodiaryKVs.moodPalette.set('blueOrange');
    expect(MoodPalette.current, MoodPalette.blueOrange);
    MoodiaryKVs.moodPalette.set('unknown');
    expect(MoodPalette.current, MoodPalette.classic);
    MoodiaryKVs.moodPalette.remove();
    expect(MoodPalette.current, MoodPalette.classic);
  });

  test('on-colors maximize WCAG contrast in every palette and brightness', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
    }

    for (final palette in MoodPalette.values) {
      for (final brightness in Brightness.values) {
        for (final mood in DiaryMood.values) {
          final fill = palette.color(mood, brightness);
          final on = palette.onColor(mood, brightness);
          const candidates = [Color(0xFFFFFFFF), Color(0xFF161616)];
          expect(candidates, contains(on));
          for (final candidate in candidates) {
            expect(
              contrast(fill, on),
              greaterThanOrEqualTo(contrast(fill, candidate)),
            );
          }
        }
      }
    }
  });

  testWidgets('all five faces and unset paint at small and large sizes', (
    tester,
  ) async {
    for (final palette in MoodPalette.values) {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          muiTestApp(
            MuiTheme(
              data: buildMuiTheme(brightness: brightness),
              child: Row(
                children: [
                  for (final size in [18.0, 30.0])
                    for (final mood in <DiaryMood?>[...DiaryMood.values, null])
                      MoodGlyph(mood: mood, size: size, palette: palette),
                ],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        for (final glyph in find.byType(MoodGlyph).evaluate()) {
          final paint = tester.widget<CustomPaint>(
            find.descendant(
              of: find.byWidget(glyph.widget),
              matching: find.byType(CustomPaint),
            ),
          );
          final recorder = ui.PictureRecorder();
          expect(
            () => paint.painter!.paint(Canvas(recorder), paint.size),
            returnsNormally,
          );
          recorder.endRecording().dispose();
        }
      }
    }
  });

  testWidgets('stored palette and brightness changes rebuild context colors', (
    tester,
  ) async {
    final brightness = ValueNotifier(Brightness.light);
    addTearDown(brightness.dispose);
    Color? fill, on;
    final consumer = Builder(
      builder: (context) {
        fill = DiaryMood.awful.colorOf(context);
        on = DiaryMood.awful.onColorOf(context);
        return const MoodGlyph(mood: .awful);
      },
    );
    await tester.pumpWidget(
      muiTestApp(
        ValueListenableBuilder<String>(
          valueListenable: MoodiaryKVs.moodPalette.getNotifier(),
          builder: (context, name, child) => MoodPaletteScope(
            palette: MoodPalette.fromName(name),
            child: child!,
          ),
          child: ValueListenableBuilder<Brightness>(
            valueListenable: brightness,
            builder: (context, value, child) => MuiTheme(
              data: buildMuiTheme(brightness: value),
              child: child!,
            ),
            child: consumer,
          ),
        ),
      ),
    );
    expect(fill, const Color(0xFFB71C1C));
    MoodiaryKVs.moodPalette.set('blueOrange');
    await tester.pumpAndSettle();
    expect(fill, const Color(0xFF2C4A9C));
    expect(on, MoodPalette.blueOrange.onColor(.awful, .light));
    brightness.value = .dark;
    await tester.pumpAndSettle();
    expect(fill, const Color(0xFF5F84DE));
    expect(on, MoodPalette.blueOrange.onColor(.awful, .dark));
  });
}
