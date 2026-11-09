part of '../moodiary_editor.dart';

bool _usesAppleSystemFont(String? family) =>
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) &&
    (family == null || family == '.AppleSystemUIFont');

List<FontVariation>? _appleOpticalSize(double size, String? family) =>
    _usesAppleSystemFont(family) ? [FontVariation('opsz', size)] : null;

// SkParagraph doesn't apply the system font's size-specific tracking.
double _appleSystemTracking(double size, String? family) {
  if (!_usesAppleSystemFont(family)) return 0;
  const points = _sfTrackingByPointSize;
  final macOS = defaultTargetPlatform == TargetPlatform.macOS;
  double tracking(int index) {
    final (point, value) = points[index];
    return macOS ? _sfTrackingMacOS[point] ?? value : value;
  }

  if (size <= points.first.$1) return tracking(0);
  for (var i = 1; i < points.length; i++) {
    final end = points[i].$1;
    if (size <= end) {
      final start = points[i - 1].$1;
      return tracking(i - 1) +
          (tracking(i) - tracking(i - 1)) * (size - start) / (end - start);
    }
  }
  return tracking(points.length - 1);
}

// (point size, tracking in points) for SF Pro, from Apple's HIG.
// https://developer.apple.com/design/human-interface-guidelines/typography#Tracking-values
const _sfTrackingByPointSize = <(double, double)>[
  (6, 0.24),
  (7, 0.23),
  (8, 0.21),
  (9, 0.17),
  (10, 0.12),
  (11, 0.06),
  (12, 0),
  (13, -0.08),
  (14, -0.15),
  (15, -0.23),
  (16, -0.31),
  (17, -0.43),
  (18, -0.44),
  (19, -0.45),
  (20, -0.45),
  (21, -0.36),
  (22, -0.26),
  (23, -0.1),
  (24, 0.07),
  (25, 0.15),
  (26, 0.22),
  (27, 0.29),
  (28, 0.38),
  (29, 0.4),
  (30, 0.4),
  (31, 0.39),
  (32, 0.41),
  (33, 0.4),
  (34, 0.4),
  (35, 0.38),
  (36, 0.37),
  (37, 0.36),
  (38, 0.37),
  (39, 0.38),
  (40, 0.37),
  (41, 0.36),
  (42, 0.37),
  (43, 0.38),
  (44, 0.37),
  (45, 0.35),
  (46, 0.36),
  (47, 0.37),
  (48, 0.35),
  (49, 0.33),
  (50, 0.34),
  (51, 0.35),
  (52, 0.33),
  (53, 0.31),
  (54, 0.32),
  (56, 0.3),
  (58, 0.28),
  (60, 0.26),
  (62, 0.24),
  (64, 0.22),
  (66, 0.19),
  (68, 0.17),
  (70, 0.14),
  (72, 0.14),
  (76, 0.07),
  (80, 0),
  (84, 0),
  (88, 0),
  (92, 0),
  (96, 0),
];

// Sizes where macOS differs from the table above.
final _sfTrackingMacOS = <double, double>{52: .31, 53: .33};
