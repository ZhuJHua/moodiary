import 'package:flutter/material.dart';
import 'package:mui/src/themes/mui_tokens.dart';
import 'package:mui/src/themes/tokens.dart';
import 'package:mui/src/themes/typography.dart';
import 'package:mui/src/themes/value.dart';

/// 主题的取用门面 —— **只读派生，不是存储**。
///
/// 真源是 material 的 [ThemeData]：配色是 [ColorScheme]、排版是 [TextTheme]，
/// 本包不再另建一套。这一层只做两件 material 表达不出来的事：
///   1. 把裸 `TextStyle` 包成可链式取色的 [MuiTextRole]（`.emphasized.<角色>`）；
///   2. 暴露 [MuiTokens] 里那些 `ThemeData` 没有槽位的东西（圆角/间距/动效…）。
///
/// 构造是廉价的（只读两个字段），[typography] 逐级懒算，所以可以在 `build` 里随手取。
@immutable
class MuiThemeData with MuiValue {
  MuiThemeData(this.raw)
    : tokens = raw.extension<MuiTokens>() ?? MuiTokens.fallback(raw.brightness);

  /// 底下的 material 主题。要整份传给第三方 API 时用它。
  final ThemeData raw;

  /// `ThemeData` 装不下的那部分。第三方自建主题的子树里取到的是兜底值。
  final MuiTokens tokens;

  Brightness get brightness => raw.brightness;

  bool get isDark => brightness == Brightness.dark;

  /// 配色。**就是 material 的色板本身**，47 个角色一个不少。
  ColorScheme get colors => raw.colorScheme;

  /// 排版。几何与字重来自 [ThemeData.textTheme]，`.emphasized` 与链式取色由 mui 补。
  late final MuiTypography typography = MuiTypography(
    raw.textTheme,
    raw.colorScheme,
    tokens.onMedia,
    tokens.font,
  );

  /// 叠在画面上的前景（缩略图角标、播放器控件…）。M3 没有这个角色。
  Color get onMedia => tokens.onMedia;

  MuiFontConfig get font => tokens.font;
  MuiRadii get radii => tokens.radii;
  MuiSpacing get spacing => tokens.spacing;
  MuiMotion get motion => tokens.motion;
  MuiBorders get borders => tokens.borders;
  MuiElevations get elevations => tokens.elevations;
  MuiStateTokens get states => tokens.states;

  /// 相等只看真源。`ThemeData` 与 [MuiTokens] 都是值语义，所以这一层不需要自己比。
  @override
  List<Object?> get props => [raw, tokens];
}
