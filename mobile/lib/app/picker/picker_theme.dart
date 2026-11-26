import 'package:flutter/material.dart' as legacy;
import 'package:mui/mui.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

legacy.ThemeData buildPickerTheme(MuiThemeData mui) {
  final colors = mui.colors;
  final base = AssetPicker.themeData(
    colors.primary,
    light: mui.brightness == Brightness.light,
  );
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      secondary: colors.primary,
      onSecondary: colors.onPrimary,
      surface: colors.surface,
      onSurface: colors.onSurface,
      error: colors.error,
    ),
    primaryColor: colors.surface,
    canvasColor: colors.surfaceContainer,
    scaffoldBackgroundColor: colors.surface,
    cardColor: colors.surface,
    dividerColor: colors.outlineVariant,
    unselectedWidgetColor: colors.outline,
    focusColor: colors.surfaceContainerHigh,
    splashColor: colors.onSurface.withValues(alpha: 0.12),
    iconTheme: legacy.IconThemeData(color: colors.onSurface),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: colors.surface,
      foregroundColor: colors.onSurface,
      iconTheme: legacy.IconThemeData(color: colors.onSurface),
    ),
    bottomAppBarTheme: base.bottomAppBarTheme.copyWith(
      color: colors.surfaceContainer,
    ),
  );
}
