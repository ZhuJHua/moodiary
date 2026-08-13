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

export 'src/themes/build.dart';
export 'src/themes/color_scheme.dart';
export 'src/themes/mui_tokens.dart';
export 'src/themes/theme.dart';
export 'src/themes/theme_data.dart';
export 'src/themes/tokens.dart';
export 'src/themes/typography.dart';
export 'src/themes/value.dart';
