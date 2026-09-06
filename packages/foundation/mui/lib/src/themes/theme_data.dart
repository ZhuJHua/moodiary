import 'package:material_ui/material_ui.dart';
import 'package:mui/src/themes/mui_tokens.dart';
import 'package:mui/src/themes/tokens.dart';
import 'package:mui/src/themes/typography.dart';
import 'package:mui/src/themes/value.dart';

@immutable
class MuiThemeData with MuiValue {
  MuiThemeData(this.raw)
    : tokens = raw.extension<MuiTokens>() ?? MuiTokens.fallback(raw.brightness);

  final ThemeData raw;

  final MuiTokens tokens;

  Brightness get brightness => raw.brightness;

  bool get isDark => brightness == Brightness.dark;

  ColorScheme get colors => raw.colorScheme;

  late final MuiTypography typography = MuiTypography(
    raw.textTheme,
    raw.colorScheme,
    tokens.onMedia,
    tokens.font,
  );

  Color get onMedia => tokens.onMedia;

  Color get success => tokens.success;

  MuiFontConfig get font => tokens.font;
  MuiRadii get radii => tokens.radii;
  MuiSpacing get spacing => tokens.spacing;
  MuiMotion get motion => tokens.motion;
  MuiBorders get borders => tokens.borders;
  MuiElevations get elevations => tokens.elevations;
  MuiStateTokens get states => tokens.states;

  @override
  List<Object?> get props => [raw, tokens];
}
