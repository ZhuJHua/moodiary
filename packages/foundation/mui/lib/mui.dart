/// mui —— Another Material Design UI。
///
/// Material Design 血统，但不是 Material：本包**只依赖 `package:flutter/widgets.dart`
/// 及以下**，零 `material` / `cupertino` import，由 `tool/check_layers.dart` 零基线守住。
///
/// 与 material 长期共存期间，`MuiThemeData` 是配色与排版的唯一真源，
/// material 的 `ThemeData` 由 core 的 `mui_material_bridge.dart` 单向投影而来。
library;

export 'src/themes/color_scheme.dart';
export 'src/themes/component_theme.dart';
export 'src/themes/state_colors.dart';
export 'src/themes/theme.dart';
export 'src/themes/theme_data.dart';
export 'src/themes/tokens.dart';
export 'src/themes/typography.dart';
export 'src/themes/value.dart';
