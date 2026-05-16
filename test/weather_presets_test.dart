import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/common/values/icons.dart';
import 'package:moodiary/common/values/weather_presets.dart';

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
}
