import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:material_ui/material_ui.dart';
import 'package:mui/src/themes/value.dart';

@immutable
class MuiFontConfig with MuiValue {
  const MuiFontConfig({this.family, this.wghtAxis = const {}});

  final String? family;
  final Map<String, double> wghtAxis;

  double get regular => wghtAxis['Regular'] ?? 400;
  double get medium => wghtAxis['Medium'] ?? 500;
  double get semiBold => wghtAxis['SemiBold'] ?? 600;
  double get bold => wghtAxis['Bold'] ?? 700;

  @override
  List<Object?> get props => [family, wghtAxis];
}

enum MuiWeight {
  regular(FontWeight.w400),
  medium(FontWeight.w500),
  semiBold(FontWeight.w600),
  bold(FontWeight.w700);

  const MuiWeight(this.value);

  final FontWeight value;

  double axis(MuiFontConfig font) => switch (this) {
    .regular => font.regular,
    .medium => font.medium,
    .semiBold => font.semiBold,
    .bold => font.bold,
  };
}

@immutable
class MuiTextRole {
  const MuiTextRole._(this._base, this._colors, this._onMedia, this._emphasis);

  final TextStyle _base;

  final ColorScheme _colors;

  final Color _onMedia;

  final TextStyle _emphasis;

  MuiTextRole get emphasized =>
      MuiTextRole._(_emphasis, _colors, _onMedia, _emphasis);

  TextStyle get onSurface => _base.copyWith(color: _colors.onSurface);
  TextStyle get onSurfaceVariant =>
      _base.copyWith(color: _colors.onSurfaceVariant);
  TextStyle get outline => _base.copyWith(color: _colors.outline);

  TextStyle get primary => _base.copyWith(color: _colors.primary);
  TextStyle get onPrimary => _base.copyWith(color: _colors.onPrimary);
  TextStyle get onPrimaryContainer =>
      _base.copyWith(color: _colors.onPrimaryContainer);

  TextStyle get secondary => _base.copyWith(color: _colors.secondary);
  TextStyle get onSecondary => _base.copyWith(color: _colors.onSecondary);
  TextStyle get onSecondaryContainer =>
      _base.copyWith(color: _colors.onSecondaryContainer);

  TextStyle get tertiary => _base.copyWith(color: _colors.tertiary);
  TextStyle get onTertiary => _base.copyWith(color: _colors.onTertiary);
  TextStyle get onTertiaryContainer =>
      _base.copyWith(color: _colors.onTertiaryContainer);

  TextStyle get error => _base.copyWith(color: _colors.error);
  TextStyle get onError => _base.copyWith(color: _colors.onError);
  TextStyle get onErrorContainer =>
      _base.copyWith(color: _colors.onErrorContainer);

  TextStyle get onInverseSurface =>
      _base.copyWith(color: _colors.onInverseSurface);
  TextStyle get inversePrimary => _base.copyWith(color: _colors.inversePrimary);

  TextStyle get onMedia => _base.copyWith(color: _onMedia);
}

const Map<String, MuiWeight> _weights = {
  'displayLarge': .regular,
  'displayMedium': .regular,
  'displaySmall': .regular,
  'headlineLarge': .regular,
  'headlineMedium': .regular,
  'headlineSmall': .regular,
  'titleLarge': .regular,
  'titleMedium': .medium,
  'titleSmall': .medium,
  'bodyLarge': .regular,
  'bodyMedium': .regular,
  'bodySmall': .regular,
  'labelLarge': .medium,
  'labelMedium': .medium,
  'labelSmall': .medium,
};

const Map<String, (double, double, double)> _geometry = {
  'displayLarge': (57, 1.12, -0.25),
  'displayMedium': (45, 1.16, 0),
  'displaySmall': (36, 1.22, 0),
  'headlineLarge': (32, 1.25, 0),
  'headlineMedium': (28, 1.29, 0),
  'headlineSmall': (24, 1.33, 0),
  'titleLarge': (22, 1.27, 0),
  'titleMedium': (16, 1.50, 0.15),
  'titleSmall': (14, 1.43, 0.1),
  'bodyLarge': (16, 1.50, 0.5),
  'bodyMedium': (14, 1.43, 0.25),
  'bodySmall': (12, 1.33, 0.4),
  'labelLarge': (14, 1.43, 0.1),
  'labelMedium': (12, 1.33, 0.5),
  'labelSmall': (11, 1.45, 0.5),
};

MuiWeight _emphasisOf(double baseSize) =>
    baseSize >= 22 ? MuiWeight.bold : MuiWeight.semiBold;

String? _platformFamily(double baseSize) => switch (defaultTargetPlatform) {
  TargetPlatform.android ||
  TargetPlatform.fuchsia ||
  TargetPlatform.linux => 'Roboto',
  TargetPlatform.iOS =>
    baseSize >= 22 ? 'CupertinoSystemDisplay' : 'CupertinoSystemText',
  TargetPlatform.macOS => '.AppleSystemUIFont',
  TargetPlatform.windows => 'Segoe UI',
};

TextStyle _styleOf(String name, MuiWeight weight, MuiFontConfig font, Color c) {
  final (baseSize, height, spacing) = _geometry[name]!;
  return TextStyle(
    inherit: false,
    color: c,
    fontFamily: font.family ?? _platformFamily(baseSize),
    fontSize: baseSize,
    height: height,
    letterSpacing: spacing,
    fontWeight: weight.value,
    fontVariations: [FontVariation('wght', weight.axis(font))],
    textBaseline: TextBaseline.alphabetic,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

TextTheme buildTextTheme(MuiFontConfig font, Color color) {
  TextStyle s(String name) => _styleOf(name, _weights[name]!, font, color);
  return TextTheme(
    displayLarge: s('displayLarge'),
    displayMedium: s('displayMedium'),
    displaySmall: s('displaySmall'),
    headlineLarge: s('headlineLarge'),
    headlineMedium: s('headlineMedium'),
    headlineSmall: s('headlineSmall'),
    titleLarge: s('titleLarge'),
    titleMedium: s('titleMedium'),
    titleSmall: s('titleSmall'),
    bodyLarge: s('bodyLarge'),
    bodyMedium: s('bodyMedium'),
    bodySmall: s('bodySmall'),
    labelLarge: s('labelLarge'),
    labelMedium: s('labelMedium'),
    labelSmall: s('labelSmall'),
  );
}

@immutable
class MuiTypography with MuiValue {
  MuiTypography(this._textTheme, this._colors, this._onMedia, this.font);

  final TextTheme _textTheme;
  final ColorScheme _colors;
  final Color _onMedia;

  final MuiFontConfig font;

  late final MuiTextRole displayLarge = _role(
    'displayLarge',
    _textTheme.displayLarge,
  );
  late final MuiTextRole displayMedium = _role(
    'displayMedium',
    _textTheme.displayMedium,
  );
  late final MuiTextRole displaySmall = _role(
    'displaySmall',
    _textTheme.displaySmall,
  );
  late final MuiTextRole headlineLarge = _role(
    'headlineLarge',
    _textTheme.headlineLarge,
  );
  late final MuiTextRole headlineMedium = _role(
    'headlineMedium',
    _textTheme.headlineMedium,
  );
  late final MuiTextRole headlineSmall = _role(
    'headlineSmall',
    _textTheme.headlineSmall,
  );
  late final MuiTextRole titleLarge = _role(
    'titleLarge',
    _textTheme.titleLarge,
  );
  late final MuiTextRole titleMedium = _role(
    'titleMedium',
    _textTheme.titleMedium,
  );
  late final MuiTextRole titleSmall = _role(
    'titleSmall',
    _textTheme.titleSmall,
  );
  late final MuiTextRole bodyLarge = _role('bodyLarge', _textTheme.bodyLarge);
  late final MuiTextRole bodyMedium = _role(
    'bodyMedium',
    _textTheme.bodyMedium,
  );
  late final MuiTextRole bodySmall = _role('bodySmall', _textTheme.bodySmall);
  late final MuiTextRole labelLarge = _role(
    'labelLarge',
    _textTheme.labelLarge,
  );
  late final MuiTextRole labelMedium = _role(
    'labelMedium',
    _textTheme.labelMedium,
  );
  late final MuiTextRole labelSmall = _role(
    'labelSmall',
    _textTheme.labelSmall,
  );

  MuiTextRole _role(String name, TextStyle? style) {
    final base = style?.fontSize == null
        ? _styleOf(name, _weights[name]!, font, _colors.onSurface)
        : style!;
    final weight = _emphasisOf(base.fontSize ?? _geometry[name]!.$1);
    return MuiTextRole._(
      base,
      _colors,
      _onMedia,
      base.copyWith(
        fontWeight: weight.value,
        fontVariations: [FontVariation('wght', weight.axis(font))],
      ),
    );
  }

  static const List<String> levels = [
    'displayLarge',
    'displayMedium',
    'displaySmall',
    'headlineLarge',
    'headlineMedium',
    'headlineSmall',
    'titleLarge',
    'titleMedium',
    'titleSmall',
    'bodyLarge',
    'bodyMedium',
    'bodySmall',
    'labelLarge',
    'labelMedium',
    'labelSmall',
  ];

  MuiTextRole byLevel(String level) => switch (level) {
    'displayLarge' => displayLarge,
    'displayMedium' => displayMedium,
    'displaySmall' => displaySmall,
    'headlineLarge' => headlineLarge,
    'headlineMedium' => headlineMedium,
    'headlineSmall' => headlineSmall,
    'titleLarge' => titleLarge,
    'titleMedium' => titleMedium,
    'titleSmall' => titleSmall,
    'bodyLarge' => bodyLarge,
    'bodyMedium' => bodyMedium,
    'bodySmall' => bodySmall,
    'labelLarge' => labelLarge,
    'labelMedium' => labelMedium,
    'labelSmall' => labelSmall,
    _ => throw ArgumentError.value(level, 'level', '不是 M3 的排版角色'),
  };

  @override
  List<Object?> get props => [_textTheme, _colors, _onMedia, font];
}
