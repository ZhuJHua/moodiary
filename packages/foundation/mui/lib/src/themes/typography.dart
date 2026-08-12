import 'package:flutter/widgets.dart';
import 'package:mui/src/themes/color_scheme.dart';
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
  const MuiTextRole._(this._base, this._colors, this._emphasis);

  final TextStyle _base;
  final MuiColorScheme _colors;

  /// 预解析好的强调档，与 [_base] 只差字重。
  final TextStyle _emphasis;

  /// 同尺寸的强调档 —— 唯一的字重入口。幂等（`emphasized.emphasized` 不再加重）。
  MuiTextRole get emphasized => MuiTextRole._(_emphasis, _colors, _emphasis);

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

  /// 叠在图片/视频上的文字，见 [MuiColorScheme.onMedia]。
  TextStyle get onMedia => _base.copyWith(color: _colors.onMedia);
}

/// 排版表。角色名与 M3 `TextTheme` 逐级同名 —— 桥的投影是 1:1，
/// 197 处 `context.textTheme.*` 零改名。
///
/// 几何手抄 M3 2021。实测 `englishLike2021 == dense2021 == tall2021`
/// （`typography.dart:2096/2114/2132` 三块逐字段相同），所以一套对 zh 与 en 都成立，
/// 不需要按 `ScriptCategory` 分档。
@immutable
class MuiTypography with MuiValue {
  const MuiTypography._({
    required this.font,
    required this.colors,
    required this.displayLarge,
    required this.displayMedium,
    required this.displaySmall,
    required this.headlineLarge,
    required this.headlineMedium,
    required this.headlineSmall,
    required this.titleLarge,
    required this.titleMedium,
    required this.titleSmall,
    required this.bodyLarge,
    required this.bodyMedium,
    required this.bodySmall,
    required this.labelLarge,
    required this.labelMedium,
    required this.labelSmall,
  });

  final MuiFontConfig font;
  final MuiColorScheme colors;

  final MuiTextRole displayLarge;
  final MuiTextRole displayMedium;
  final MuiTextRole displaySmall;
  final MuiTextRole headlineLarge;
  final MuiTextRole headlineMedium;
  final MuiTextRole headlineSmall;
  final MuiTextRole titleLarge;
  final MuiTextRole titleMedium;
  final MuiTextRole titleSmall;
  final MuiTextRole bodyLarge;
  final MuiTextRole bodyMedium;
  final MuiTextRole bodySmall;
  final MuiTextRole labelLarge;
  final MuiTextRole labelMedium;
  final MuiTextRole labelSmall;

  /// 15 个角色由这两者**确定性地**算出，所以相等只比这两个。
  /// 多比 15 份 `TextStyle` 既慢又不会给出不同答案。
  @override
  List<Object?> get props => [font, colors];

  /// 每一级的默认字重 —— **M3 2021 的原值**，与 `Typography.englishLike2021`
  /// 逐级相同（`typography.dart:2096`）：15 级里 10 级 Regular，只有 title 的
  /// medium/small 与三个 label 是 Medium。M3 里没有 600/700。
  ///
  /// 这张表以前是本仓 mui 之前那套自定义字重（display 500 / headlineLarge 700 /
  /// titleLarge 600…），既不是 M3、内部也不自洽（titleLarge 600 但 titleSmall 500、
  /// labelMedium 500 但 labelSmall 400），于是调用点一路用 `.semiBold` 打补丁。
  static const Map<String, MuiWeight> _weights = {
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

  /// 强调档按**光学尺寸**分两级：22px 及以上用 Bold，其余用 SemiBold。
  ///
  /// 取自 iOS HIG 的做法（Large Title / Title 1 / Title 2 的 emphasized 是 Bold，
  /// Title 3 及以下是 Semibold）。理由是字越大越需要更强的字重反差才看得出加重，
  /// 而正文尺寸上 Bold 会显得脏。M3 2021 本身没有定义强调档。
  static MuiWeight _emphasisOf(double baseSize) =>
      baseSize >= 22 ? MuiWeight.bold : MuiWeight.semiBold;

  /// M3 2021 的几何，与 `Typography.englishLike2021` 逐级逐字段相同
  /// （`typography.dart:2096`，由 `theme_projection_test` 对拍）：
  /// fontSize / height / letterSpacing。[height] 是**比例**不是绝对行高。
  ///
  /// 字号**不在这里缩放** —— 跟随系统字体大小，由 `MediaQuery.textScaler`
  /// 在渲染期施加，这是平台无障碍设置的唯一入口。
  static const Map<String, (double, double, double)> _geometry = {
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

  static MuiTextRole _role(
    String name,
    MuiFontConfig font,
    MuiColorScheme colors,
  ) {
    final (baseSize, height, spacing) = _geometry[name]!;
    TextStyle styleOf(MuiWeight weight) => TextStyle(
      inherit: false,
      color: colors.onSurface,
      fontFamily: font.family,
      fontSize: baseSize,
      height: height,
      letterSpacing: spacing,
      fontWeight: weight.value,
      fontVariations: [FontVariation('wght', weight.axis(font))],
      textBaseline: .alphabetic,
      leadingDistribution: .even,
    );
    return MuiTextRole._(
      styleOf(_weights[name]!),
      colors,
      styleOf(_emphasisOf(baseSize)),
    );
  }

  factory MuiTypography.resolve({
    required MuiFontConfig font,
    required MuiColorScheme colors,
  }) {
    MuiTextRole r(String name) => _role(name, font, colors);
    return MuiTypography._(
      font: font,
      colors: colors,
      displayLarge: r('displayLarge'),
      displayMedium: r('displayMedium'),
      displaySmall: r('displaySmall'),
      headlineLarge: r('headlineLarge'),
      headlineMedium: r('headlineMedium'),
      headlineSmall: r('headlineSmall'),
      titleLarge: r('titleLarge'),
      titleMedium: r('titleMedium'),
      titleSmall: r('titleSmall'),
      bodyLarge: r('bodyLarge'),
      bodyMedium: r('bodyMedium'),
      bodySmall: r('bodySmall'),
      labelLarge: r('labelLarge'),
      labelMedium: r('labelMedium'),
      labelSmall: r('labelSmall'),
    );
  }

  /// 全部 15 级的角色名，供投影与测试遍历。
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

  static MuiTypography lerp(MuiTypography a, MuiTypography b, double t) {
    if (identical(a, b)) return a;
    // 排版由 (font, colors) 确定，所以补间只要拿插值后的色板重解析一次。
    // 逐级 TextStyle.lerp 会算 15 次却得到同样的结果。
    return MuiTypography.resolve(
      font: t < 0.5 ? a.font : b.font,
      colors: MuiColorScheme.lerp(a.colors, b.colors, t),
    );
  }
}
