import 'package:flutter/widgets.dart';
import 'package:mui/src/themes/color_scheme.dart';
import 'package:mui/src/themes/component_theme.dart';
import 'package:mui/src/themes/tokens.dart';
import 'package:mui/src/themes/typography.dart';
import 'package:mui/src/themes/value.dart';

/// mui 的主题真源。
///
/// 共存期 material 的 `ThemeData` 是它的**只读投影**（见 core 的
/// `mui_material_bridge.dart`），单向、无回读，两棵主题树因此不可能漂。
///
/// 硬规则：
///   * 任何字段**不得持有闭包**（`WidgetStateProperty` / `Function` / `Builder`），
///     否则整个值语义地基失效，见 [MuiStateColors] 的说明。
///   * `==` 与 `lerp` 必须覆盖全部字段。前者靠 [MuiValue] 的 props 收成一处，
///     后者只能手写 —— 由 `theme_field_coverage_test.dart` 钉住两边的字段数。
///   * 只在 controller 层构造，`build` 方法里永远不 new。
@immutable
class MuiThemeData with MuiValue {
  const MuiThemeData._({
    required this.brightness,
    required this.colors,
    required this.typography,
    required this.font,
    required this.textSize,
    required this.radii,
    required this.spacing,
    required this.motion,
    required this.borders,
    required this.elevations,
    required this.states,
    required this.icons,
    required this.components,
    required this.extensions,
  });

  /// 唯一的构造入口。工厂内解析色板与排版，[components] / [extensions]
  /// 按类型键折叠成 map，结果字段全部非空 —— 组件取主题不判空。
  factory MuiThemeData({
    required Brightness brightness,
    MuiAccent accent = const .neutral(),
    MuiColorScheme? colors,
    MuiFontConfig font = const MuiFontConfig(),
    MuiTextSize textSize = MuiTextSize.large,
    MuiRadii radii = const MuiRadii(),
    MuiSpacing spacing = const MuiSpacing(),
    MuiMotion motion = const MuiMotion(),
    MuiBorders borders = const MuiBorders(),
    MuiElevations? elevations,
    MuiStateTokens states = const MuiStateTokens(),
    MuiIconThemeData? icons,
    List<MuiComponentTheme<dynamic>> components = const [],
    List<MuiThemeExtension<dynamic>> extensions = const [],
  }) {
    final scheme = colors ?? MuiColorScheme.resolve(brightness, accent);
    return MuiThemeData._(
      brightness: brightness,
      colors: scheme,
      typography: MuiTypography.resolve(
        size: textSize,
        font: font,
        colors: scheme,
      ),
      font: font,
      textSize: textSize,
      radii: radii,
      spacing: spacing,
      motion: motion,
      borders: borders,
      elevations: elevations ?? MuiElevations.of(brightness),
      states: states,
      icons: icons ?? MuiIconThemeData(color: scheme.onSurface),
      components: {for (final c in components) c.typeKey: c},
      extensions: {for (final e in extensions) e.typeKey: e},
    );
  }

  final Brightness brightness;
  final MuiColorScheme colors;
  final MuiTypography typography;
  final MuiFontConfig font;
  final MuiTextSize textSize;
  final MuiRadii radii;
  final MuiSpacing spacing;
  final MuiMotion motion;
  final MuiBorders borders;
  final MuiElevations elevations;
  final MuiStateTokens states;
  final MuiIconThemeData icons;
  final Map<Object, MuiComponentTheme<dynamic>> components;
  final Map<Object, MuiThemeExtension<dynamic>> extensions;

  @override
  List<Object?> get props => [
    brightness,
    colors,
    typography,
    font,
    textSize,
    radii,
    spacing,
    motion,
    borders,
    elevations,
    states,
    icons,
    components,
    extensions,
  ];

  T? component<T extends MuiComponentTheme<T>>() => components[T] as T?;

  T? extension<T extends MuiThemeExtension<T>>() => extensions[T] as T?;

  /// 子树局部覆盖：把 [data] 当补丁叠在已有同型主题上。
  ///
  /// 会复制一次 components map（通常 0-3 个条目，代价可忽略），但别写在每帧 build 里。
  MuiThemeData withComponent<T extends MuiComponentTheme<T>>(T data) {
    final merged = component<T>()?.merge(data) ?? data;
    return _copyWith(components: {...components, T: merged});
  }

  MuiThemeData withExtension<T extends MuiThemeExtension<T>>(T data) =>
      _copyWith(extensions: {...extensions, T: data});

  MuiThemeData _copyWith({
    Map<Object, MuiComponentTheme<dynamic>>? components,
    Map<Object, MuiThemeExtension<dynamic>>? extensions,
  }) => MuiThemeData._(
    brightness: brightness,
    colors: colors,
    typography: typography,
    font: font,
    textSize: textSize,
    radii: radii,
    spacing: spacing,
    motion: motion,
    borders: borders,
    elevations: elevations,
    states: states,
    icons: icons,
    components: components ?? this.components,
    extensions: extensions ?? this.extensions,
  );

  /// 深浅色与三态配色切换时的补间。
  ///
  /// 只对**视觉上会跳**的三项插值（[colors] / [typography] / [elevations]），
  /// 其余 token 走 `t < 0.5` 硬切 —— 全字段 lerp 是永久维护税，而中途取一半的
  /// 圆角或一半的时长没有任何意义。
  static MuiThemeData lerp(MuiThemeData a, MuiThemeData b, double t) {
    if (identical(a, b)) return a;
    final second = t < 0.5 ? a : b;
    return MuiThemeData._(
      brightness: second.brightness,
      colors: MuiColorScheme.lerp(a.colors, b.colors, t),
      typography: MuiTypography.lerp(a.typography, b.typography, t),
      font: second.font,
      textSize: second.textSize,
      radii: second.radii,
      spacing: second.spacing,
      motion: second.motion,
      borders: second.borders,
      elevations: MuiElevations.lerp(a.elevations, b.elevations, t),
      states: second.states,
      icons: MuiIconThemeData.lerp(a.icons, b.icons, t),
      components: _lerpMap(a.components, b.components, t),
      extensions: _lerpMap(a.extensions, b.extensions, t),
    );
  }

  static Map<Object, V> _lerpMap<V>(
    Map<Object, V> a,
    Map<Object, V> b,
    double t,
  ) {
    if (a.isEmpty && b.isEmpty) return const {};
    final out = <Object, V>{};
    for (final k in {...a.keys, ...b.keys}) {
      final x = a[k];
      final y = b[k];
      if (x == null || y == null) {
        out[k] = (t < 0.5 ? x ?? y : y ?? x) as V;
      } else if (x.runtimeType == y.runtimeType) {
        out[k] = (x as dynamic).lerpTo(y, t) as V;
      } else {
        out[k] = t < 0.5 ? x : y;
      }
    }
    return out;
  }
}
