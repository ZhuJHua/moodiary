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

  testWidgets('glyph is a circle bone only inside an enabled skeleton', (
    tester,
  ) async {
    for (final enabled in [true, false]) {
      await tester.pumpWidget(
        muiTestApp(
          MSkeleton(
            enabled: enabled,
            child: const MoodGlyph(mood: .great, size: 30),
          ),
        ),
      );
      expect(tester.getSize(find.byType(MoodGlyph)), const Size.square(30));
      final bones = find.byWidgetPredicate((widget) => widget is Bone);
      expect(bones, enabled ? findsOneWidget : findsNothing);
      if (enabled) {
        expect(tester.getSize(bones), const Size.square(30));
        expect(
          find.descendant(
            of: find.byType(MoodGlyph),
            matching: find.byType(CustomPaint),
          ),
          findsNothing,
        );
      } else {
        expect(
          find.descendant(
            of: find.byType(MoodGlyph),
            matching: find.byType(CustomPaint),
          ),
          findsOneWidget,
        );
      }
    }
  });

  test('palette storage defaults and round-trips stable names', () {
    expect(MoodiaryKVs.moodPalette.get(), 'classic');
    expect(
      MoodPalette.fromName(MoodiaryKVs.moodPalette.get()),
      MoodPalette.classic,
    );
    MoodiaryKVs.moodPalette.set('blueOrange');
    expect(
      MoodPalette.fromName(MoodiaryKVs.moodPalette.get()),
      MoodPalette.blueOrange,
    );
    MoodiaryKVs.moodPalette.set('unknown');
    expect(
      MoodPalette.fromName(MoodiaryKVs.moodPalette.get()),
      MoodPalette.classic,
    );
    MoodiaryKVs.moodPalette.remove();
    expect(
      MoodPalette.fromName(MoodiaryKVs.moodPalette.get()),
      MoodPalette.classic,
    );
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
    expect(
      fill,
      MoodPalette.classic.color(
        .awful,
        buildMuiTheme(brightness: .light).colorScheme,
      ),
    );
    MoodiaryKVs.moodPalette.set('blueOrange');
    await tester.pumpAndSettle();
    expect(
      fill,
      MoodPalette.blueOrange.color(
        .awful,
        buildMuiTheme(brightness: .light).colorScheme,
      ),
    );
    expect(
      on,
      MoodPalette.blueOrange.onColor(
        .awful,
        buildMuiTheme(brightness: .light).colorScheme,
      ),
    );
    brightness.value = .dark;
    await tester.pumpAndSettle();
    expect(
      fill,
      MoodPalette.blueOrange.color(
        .awful,
        buildMuiTheme(brightness: .dark).colorScheme,
      ),
    );
    expect(
      on,
      MoodPalette.blueOrange.onColor(
        .awful,
        buildMuiTheme(brightness: .dark).colorScheme,
      ),
    );
  });
}
