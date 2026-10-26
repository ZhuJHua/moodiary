import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_models/moodiary_models.dart';

// sRGB -> linear RGB -> OKLab, with Euclidean deltaE scaled by 100.
(double, double, double) _oklab(Color color) {
  double linear(double c) =>
      c <= .04045 ? c / 12.92 : math.pow((c + .055) / 1.055, 2.4).toDouble();
  final r = linear(color.r), g = linear(color.g), b = linear(color.b);
  final l = math.pow(
    .4122214708 * r + .5363325363 * g + .0514459929 * b,
    1 / 3,
  );
  final m = math.pow(
    .2119034982 * r + .6806995451 * g + .1073969566 * b,
    1 / 3,
  );
  final s = math.pow(
    .0883024619 * r + .2817188376 * g + .6299787005 * b,
    1 / 3,
  );
  return (
    .2104542553 * l + .7936177850 * m - .0040720468 * s,
    1.9779984951 * l - 2.4285922050 * m + .4505937099 * s,
    .0259040371 * l + .7827717662 * m - .8086757660 * s,
  );
}

double _deltaE(Color first, Color second) {
  final (l1, a1, b1) = _oklab(first);
  final (l2, a2, b2) = _oklab(second);
  return 100 *
      math.sqrt(
        math.pow(l1 - l2, 2) + math.pow(a1 - a2, 2) + math.pow(b1 - b2, 2),
      );
}

void main() {
  const originals = {
    MoodPalette.classic: [
      [0xFFD4382F, 0xFFF0936B, 0xFFD8D5CD, 0xFF79C26A, 0xFF2A9356],
      [0xFFEF5A50, 0xFFF7B08F, 0xFF66645F, 0xFF8FD27F, 0xFF34A35B],
    ],
    MoodPalette.blueOrange: [
      [0xFF4467C4, 0xFF89A8E2, 0xFFD4D1C9, 0xFFF2A13E, 0xFFD45A1E],
      [0xFF5F84DE, 0xFFA3BDEE, 0xFF6B6964, 0xFFF4B35E, 0xFFE06A2C],
    ],
  };
  for (final brightness in Brightness.values) {
    for (final palette in MoodPalette.values) {
      test('$palette $brightness neutral theme preserves original fills', () {
        final colors = buildMuiTheme(brightness: brightness).colorScheme;
        final expected = originals[palette]![brightness == .light ? 0 : 1];
        for (final mood in DiaryMood.values) {
          expect(palette.color(mood, colors), Color(expected[mood.index]));
          expect(
            palette.onColor(mood, colors),
            Color.lerp(
              Color(expected[mood.index]),
              const Color(0xFF000000),
              .75,
            ),
          );
        }
      });
      for (final seed in [
        0xFF2E59A7,
        0xFF6B7A3A,
        0xFFB33C86,
        0xFF6750A4,
        0xFF00897B,
      ]) {
        test(
          '$palette $brightness seed ${seed.toRadixString(16)} keeps adjacent moods distinct',
          () {
            final colors = buildMuiTheme(
              brightness: brightness,
              accent: MuiAccent.seeded(Color(seed)),
            ).colorScheme;
            final fills = [
              for (final mood in DiaryMood.values) palette.color(mood, colors),
            ];
            for (var i = 0; i < fills.length - 1; i++) {
              expect(
                _deltaE(fills[i], fills[i + 1]),
                greaterThanOrEqualTo(13),
                reason: '${DiaryMood.values[i]} -> ${DiaryMood.values[i + 1]}',
              );
            }
            for (final mood in DiaryMood.values) {
              expect(
                fills[mood.index],
                colors.harmonize(
                  Color(
                    originals[palette]![brightness == .light
                        ? 0
                        : 1][mood.index],
                  ),
                ),
              );
              expect(
                palette.onColor(mood, colors),
                Color.lerp(fills[mood.index], const Color(0xFF000000), .75),
              );
            }
            expect(
              fills,
              isNot(
                originals[palette]![brightness == .light ? 0 : 1]
                    .map(Color.new)
                    .toList(),
              ),
            );
          },
        );
      }
    }
  }
}
