// 全仓唯一还 import legacy material 的文件。
//
// wechat_assets_picker 的内部组件（AssetPickerAppBar、权限遮罩、相册面板的水波纹、
// AssetPickerViewer）只认 legacy `ThemeData`，而 `AssetPicker.themeData(...)` 也是
// 从零构造 legacy 主题。我们覆写不到的那些地方靠这一份把 App 的配色喂进去。
//
// **只有这一个文件需要它**：delegate 本身是纯 mui 的 —— material_ui 的 `Theme` 与
// legacy 的 `Theme` 是两个不同的 widget 类型，所以 picker 内部那句
// `Theme(data: pickerTheme)` 盖不住 mui 的取用链，delegate 里 `context.theme`
// 拿到的仍然是 App 的真主题。
import 'package:flutter/material.dart' as legacy;
import 'package:mui/mui.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

/// 把 mui 主题翻译成 picker 内部要的那份 legacy [legacy.ThemeData]。
///
/// 以包内置的灰黑模板为底，只覆盖取色槽位 —— picker 按自有槽位取色：
/// 强调色 = `colorScheme.secondary`、网格底 = `scaffoldBackgroundColor`、
/// 相册面板 = `canvasColor`、相册胶囊 = `focusColor`。
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
