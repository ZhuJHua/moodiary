import 'package:material_ui/material_ui.dart';
import 'package:mui/src/themes/tokens.dart';
import 'package:mui/src/themes/typography.dart';
import 'package:mui/src/themes/value.dart';

@immutable
class MuiTokens extends ThemeExtension<MuiTokens> with MuiValue {
  const MuiTokens({
    required this.onMedia,
    required this.success,
    required this.info,
    required this.warning,
    required this.font,
    required this.radii,
    required this.spacing,
    required this.motion,
    required this.borders,
    required this.elevations,
    required this.states,
  });

  final Color onMedia;

  final Color success;
  final Color info;
  final Color warning;

  final MuiFontConfig font;
  final MuiRadii radii;
  final MuiSpacing spacing;
  final MuiMotion motion;
  final MuiBorders borders;
  final MuiElevations elevations;
  final MuiStateTokens states;

  @override
  List<Object?> get props => [
    onMedia,
    success,
    info,
    warning,
    font,
    radii,
    spacing,
    motion,
    borders,
    elevations,
    states,
  ];

  @override
  MuiTokens copyWith({
    Color? onMedia,
    Color? success,
    Color? info,
    Color? warning,
    MuiFontConfig? font,
    MuiRadii? radii,
    MuiSpacing? spacing,
    MuiMotion? motion,
    MuiBorders? borders,
    MuiElevations? elevations,
    MuiStateTokens? states,
  }) => MuiTokens(
    onMedia: onMedia ?? this.onMedia,
    success: success ?? this.success,
    info: info ?? this.info,
    warning: warning ?? this.warning,
    font: font ?? this.font,
    radii: radii ?? this.radii,
    spacing: spacing ?? this.spacing,
    motion: motion ?? this.motion,
    borders: borders ?? this.borders,
    elevations: elevations ?? this.elevations,
    states: states ?? this.states,
  );

  @override
  MuiTokens lerp(ThemeExtension<MuiTokens>? other, double t) {
    if (other is! MuiTokens) return this;
    final second = t < 0.5 ? this : other;
    return MuiTokens(
      onMedia: Color.lerp(onMedia, other.onMedia, t)!,
      success: Color.lerp(success, other.success, t)!,
      info: Color.lerp(info, other.info, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      font: second.font,
      radii: second.radii,
      spacing: second.spacing,
      motion: second.motion,
      borders: second.borders,
      elevations: MuiElevations.lerp(elevations, other.elevations, t),
      states: second.states,
    );
  }

  static Color successFor(Brightness brightness) =>
      brightness == .dark ? const Color(0xFF7CD992) : const Color(0xFF1E7F4F);

  static Color infoFor(Brightness brightness) =>
      brightness == .dark ? const Color(0xFFB4C5FF) : const Color(0xFF0053DB);

  static Color warningFor(Brightness brightness) =>
      brightness == .dark ? const Color(0xFFFFB95F) : const Color(0xFF855300);

  factory MuiTokens.fallback(Brightness brightness) => MuiTokens(
    onMedia: const Color(0xFFFFFFFF),
    success: successFor(brightness),
    info: infoFor(brightness),
    warning: warningFor(brightness),
    font: const MuiFontConfig(),
    radii: const MuiRadii(),
    spacing: const MuiSpacing(),
    motion: const MuiMotion(),
    borders: const MuiBorders(),
    elevations: MuiElevations.of(brightness),
    states: const MuiStateTokens(),
  );
}
