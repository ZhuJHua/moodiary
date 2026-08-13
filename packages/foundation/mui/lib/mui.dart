/// mui —— Another Material Design UI。
///
/// 定位是 material 的**补充**，不是替代：配色用 [ColorScheme]、排版用 [TextTheme]，
/// 本包不再自建一套色板。mui 只提供 material 表达不出来的那部分 ——
///
///   * `context.theme.typography.<级>.emphasized.<颜色角色>` 的链式取用；
///   * `MuiTokens`（圆角/间距/动效/描边/投影/状态 + onMedia），挂在
///     `ThemeData.extensions` 上；
///   * `buildMuiTheme`，全仓唯一构造 [ThemeData] 的地方。
///
/// 组件层面同理：material 够用的直接用，不够用的才在本包里补，命名一律 `M` 开头。
library;

// material 本体由 mui 转发：业务代码只 import mui，不再直接碰
// package:flutter/material.dart（它将于 2026-11 弃用）。
export 'package:material_ui/material_ui.dart';

// owner 包转发：toast/浮层宿主与图标库由 mui 出，调用方不必各自 import。
export 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
export 'package:lucide_icons_flutter/lucide_icons.dart';

export 'src/components.dart';
export 'src/l10n/mui_translation_scope.dart';
export 'src/themes/build.dart';
export 'src/themes/color_scheme.dart';
export 'src/themes/mui_tokens.dart';
export 'src/themes/theme.dart';
export 'src/themes/theme_data.dart';
export 'src/themes/tokens.dart';
export 'src/themes/typography.dart';
export 'src/themes/value.dart';
