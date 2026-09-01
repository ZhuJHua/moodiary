import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:material_ui/material_ui.dart';
import 'package:mui/src/themes/value.dart';

/// 字体族 + 可变字体的 wght 轴实测值。
///
/// [wghtAxis] 由宿主从 ttf/otf 实读后注入（键为归一化后的字重名）；读不到就回落到
/// 标准档。[family] 为 null 表示用平台默认字体。
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

/// 字重档。[value] 喂 `fontWeight`，[axis] 喂可变字体的 wght 轴。
///
/// 两者**必须同时设**：可变字体下 `fontVariations` 会吃掉后来的
/// `copyWith(fontWeight:)`（`start_page.dart:225` 踩过）。所以字重只由排版级决定，
/// 调用点唯一能做的是取 [MuiTextRole.emphasized]；裸 `copyWith(fontWeight:)` 由 CI 拦。
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

/// 一个排版角色。链式读法：**先几何，再强调（可选），最后颜色**。
///
/// ```dart
/// context.theme.typography.titleLarge.onSurfaceVariant
/// context.theme.typography.bodyMedium.emphasized.primary
/// ```
///
/// **字重不是调用点的自由度**：每一级自带默认字重（M3 2021 的原值），需要在同一
/// 尺寸上加重时只有 [emphasized] 一个替身，没有 regular/medium/semiBold/bold 四个
/// 旋钮。给了旋钮的结果就是同一种语义在十几个文件里被拧成十几个值 —— 这正是
/// 迁移前的状态。要更轻不是调字重，是换级（`titleSmall` → `bodyMedium` 同为 14px）。
///
/// 刻意**不继承 `TextStyle`**：`TextStyle.operator ==` 头一句就是
/// `if (other.runtimeType != runtimeType) return false`，子类因此永远不等于普通
/// `TextStyle`，会静默破坏 `AnimatedDefaultTextStyle` 的补间判定与主题相等。
/// 代价是 `Text(style: theme.typography.bodyMedium)` 编译不过 —— 这是**有意的**：
/// 颜色必须显式指名，不许糊里糊涂继承。
///
/// 色板之外的颜色（分类哈希色、心情渐变这类业务语义色）不另开口子，
/// 落到任一角色后按惯例 `copyWith`：
/// `theme.typography.labelSmall.onSurface.copyWith(color: categoryColor)`。
@immutable
class MuiTextRole {
  const MuiTextRole._(this._base, this._colors, this._onMedia, this._emphasis);

  final TextStyle _base;

  /// material 的色板本身就是配色真源，这里直接持有它，不再包一层。
  final ColorScheme _colors;

  /// M3 没有的那一个角色，来自 `MuiTokens`。
  final Color _onMedia;

  /// 预解析好的强调档，与 [_base] 只差字重。
  final TextStyle _emphasis;

  /// 同尺寸的强调档 —— 唯一的字重入口。幂等（`emphasized.emphasized` 不再加重）。
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

  /// 叠在图片/视频上的文字，见 `MuiTokens.onMedia`。
  TextStyle get onMedia => _base.copyWith(color: _onMedia);
}

/// 每一级的默认字重 —— **M3 2021 的原值**，与 `Typography.englishLike2021` 逐级相同
/// （`typography.dart:2096`）：15 级里 10 级 Regular，只有 title 的 medium/small
/// 与三个 label 是 Medium。M3 里没有 600/700。
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

/// M3 2021 的几何，与 `Typography.englishLike2021` 逐级逐字段相同：
/// fontSize / height / letterSpacing。height 是**比例**不是绝对行高。
///
/// 字号**不在这里缩放** —— 跟随系统字体大小，由 `MediaQuery.textScaler` 在渲染期
/// 施加，这是平台无障碍设置的唯一入口。
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

/// 强调档按**光学尺寸**分两级：22px 及以上用 Bold，其余用 SemiBold。
///
/// 取自 iOS HIG 的做法（Large Title / Title 1 / Title 2 的 emphasized 是 Bold，
/// Title 3 及以下是 Semibold）。字越大越需要更强的字重反差才看得出加重，
/// 而正文尺寸上 Bold 会显得脏。M3 2021 本身没有定义强调档。
MuiWeight _emphasisOf(double baseSize) =>
    baseSize >= 22 ? MuiWeight.bold : MuiWeight.semiBold;

/// 平台默认字体族，逐平台抄 material 的 `Typography._withPlatform`
/// （`typography.dart:219`）。
///
/// **不能留空**：`fontFamily` 为 null 时由引擎自行回退，中文环境下西文与数字常常
/// 落到 CJK 字体自带的拉丁字形上 —— 那套字形为了塞进方块字的字宽被压窄，
/// 观感就是「英文和数字被压扁」。material 从来没留过这个空。
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
    // 宿主选了自定义字体就用它，否则回落到平台默认族（不是留空）。
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

/// 喂给 `ThemeData.textTheme` 的 15 级排版。
///
/// 全部 `inherit: false`，所以它会**整块替换**而不是 merge 掉默认排版
/// （`TextStyle.merge` 遇到 `inherit == false` 直接返回对方）。连带地
/// `ThemeData.localize` 那条按 `ScriptCategory` 换几何的路径变成空操作 —— 这是好事：
/// 实测 `englishLike2021 == dense2021 == tall2021`，本来就没有分档。
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

/// 排版的取用门面。**真源是 `ThemeData.textTheme`** —— 这一层只负责把
/// material 的 15 个裸 `TextStyle` 包成可链式取色的 [MuiTextRole]，
/// 并按光学尺寸算出强调档。
///
/// 换句话说：几何与字重存在 [TextTheme] 里，`.emphasized` 与 `.<颜色角色>`
/// 是 material 表达不出来的那部分表达力，由这里补。
///
/// 逐级**懒算**：用不到的级别不构造，主题动画每帧只付实际读到的那一两级。
@immutable
class MuiTypography with MuiValue {
  MuiTypography(this._textTheme, this._colors, this._onMedia, this.font);

  final TextTheme _textTheme;
  final ColorScheme _colors;
  final Color _onMedia;

  /// 可变字体的 wght 轴实测值。[MuiTextRole.emphasized] 靠它设 `fontVariations`。
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

  /// 回落到 M3 基准值的两种情形，都来自「宿主的 `ThemeData` 不是 mui 建的」：
  ///   * [style] 为 null —— 那一级压根没填；
  ///   * [style] 有值但 `fontSize` 为 null —— **裸 `ThemeData` 在 `MaterialApp`
  ///     之外就是这样**：`textTheme` 此时只有 `typography.black` 的颜色，几何要等
  ///     `ThemeData.localize` 把 `englishLike` 合进来才有。第三方自建主题的子树
  ///     （wechat picker 等）会走到这条。
  ///
  /// 颜色不用管：链式取色的 getter 一律 `copyWith(color:)` 覆盖。
  MuiTextRole _role(String name, TextStyle? style) {
    final base = style?.fontSize == null
        ? _styleOf(name, _weights[name]!, font, _colors.onSurface)
        : style!;
    final weight = _emphasisOf(base.fontSize ?? _geometry[name]!.$1);
    return MuiTextRole._(
      base,
      _colors,
      _onMedia,
      // fontWeight 与 fontVariations 必须同时设：可变字体下只改前者会被后者吃掉。
      base.copyWith(
        fontWeight: weight.value,
        fontVariations: [FontVariation('wght', weight.axis(font))],
      ),
    );
  }

  /// 全部 15 级的角色名，供测试遍历。
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

  /// 15 个角色由这四者**确定性地**算出，所以相等只比这四个。
  @override
  List<Object?> get props => [_textTheme, _colors, _onMedia, font];
}
