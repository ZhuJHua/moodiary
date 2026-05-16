import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/common/values/icons.dart';
import 'package:moodiary/common/values/weather_presets.dart';
import 'package:moodiary/l10n/app_localizations.dart';

void main() {
  group('kWeatherPresets', () {
    test('contains exactly 14 presets', () {
      expect(kWeatherPresets.length, 14);
    });

    test('every preset code exists in WeatherIcon.map', () {
      for (final preset in kWeatherPresets) {
        expect(
          WeatherIcon.map.containsKey(preset.code),
          true,
          reason: 'preset code ${preset.code} (${preset.nameKey}) '
              'is missing from WeatherIcon.map',
        );
      }
    });

    test('every preset has a non-empty nameKey', () {
      for (final preset in kWeatherPresets) {
        expect(preset.nameKey.isNotEmpty, true);
      }
    });

    test('preset codes are unique', () {
      final codes = kWeatherPresets.map((p) => p.code).toList();
      expect(codes.toSet().length, codes.length);
    });
  });

  testWidgets('WeatherPresetL10n.label resolves every nameKey', (tester) async {
    await tester.pumpWidget(const _LabelHarness());
    final BuildContext context = tester.element(find.byType(SizedBox));

    for (final preset in kWeatherPresets) {
      final label = preset.label(context);
      expect(label.isNotEmpty, true,
          reason: '${preset.nameKey} returned empty label');
      expect(label, isNot(equals(preset.nameKey)),
          reason: '${preset.nameKey} fell through to default branch');
    }
  });
}

class _LabelHarness extends StatelessWidget {
  const _LabelHarness();
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('zh'),
      home: SizedBox(),
    );
  }
}
