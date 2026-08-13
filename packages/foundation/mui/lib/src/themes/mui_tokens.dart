import 'package:material_ui/material_ui.dart';
import 'package:mui/src/themes/tokens.dart';
import 'package:mui/src/themes/typography.dart';
import 'package:mui/src/themes/value.dart';

/// material 的 [ThemeData] 装不下的那部分主题，全部收在这一个扩展里。
///
/// 颜色**不在这里** —— [ColorScheme] 就是配色真源，本包不再另建一套色板。
/// 唯一的例外是 [onMedia]：它在 M3 里没有对应角色，且不参与 on\* 配对。
///
/// [font] 必须留在主题里，不能靠 `TextStyle.fontWeight` 反推 ——
/// [MuiTextRole.emphasized] 要同时设 `fontWeight` 与 `fontVariations`，而后者的轴值
/// 只有宿主读过 ttf 才知道。`ThemeData` 没有任何槽位放它，漏了就会在自定义可变字体
/// 下静默出错字重。
@immutable
class MuiTokens extends ThemeExtension<MuiTokens> with MuiValue {
  const MuiTokens({
    required this.onMedia,
    required this.font,
    required this.radii,
    required this.spacing,
    required this.motion,
    required this.borders,
    required this.elevations,
    required this.states,
  });

  /// 叠在**画面**上的前景：缩略图角标、播放器控件、图片浏览器、心情色带上的描边。
  ///
  /// 底不可预测（用户的照片可以是任何颜色），所以它既不跟明暗档变，也不参与 on\*
  /// 配对 —— 深浅两档同为纯白，靠调用点自己压 scrim/阴影保证对比度。
  /// 有这个槽位是为了让「这里为什么是白的」写在代码里，而不是散落的 `Colors.white`。
  final Color onMedia;

  final MuiFontConfig font;
  final MuiRadii radii;
  final MuiSpacing spacing;
  final MuiMotion motion;
  final MuiBorders borders;
  final MuiElevations elevations;
  final MuiStateTokens states;

  @override
  List<Object?> get props => [
    onMedia,
    font,
    radii,
    spacing,
    motion,
    borders,
    elevations,
    states,
  ];

  @override
  MuiTokens copyWith({
    Color? onMedia,
    MuiFontConfig? font,
    MuiRadii? radii,
    MuiSpacing? spacing,
    MuiMotion? motion,
    MuiBorders? borders,
    MuiElevations? elevations,
    MuiStateTokens? states,
  }) => MuiTokens(
    onMedia: onMedia ?? this.onMedia,
    font: font ?? this.font,
    radii: radii ?? this.radii,
    spacing: spacing ?? this.spacing,
    motion: motion ?? this.motion,
    borders: borders ?? this.borders,
    elevations: elevations ?? this.elevations,
    states: states ?? this.states,
  );

  /// `ThemeData.lerp` 只对**两边都存在且 runtimeType 相同**的扩展调这个方法，
  /// 所以 `buildMuiTheme` 必须给深浅两档都无条件挂上 [MuiTokens]，缺一边就整个
  /// 不插值、主题切换时这些值会硬跳。
  ///
  /// 只插视觉上会跳的投影，其余 token 走 `t < 0.5` 硬切 —— 中途取一半的圆角
  /// 或一半的时长没有意义。
  @override
  MuiTokens lerp(ThemeExtension<MuiTokens>? other, double t) {
    if (other is! MuiTokens) return this;
    final second = t < 0.5 ? this : other;
    return MuiTokens(
      onMedia: Color.lerp(onMedia, other.onMedia, t)!,
      font: second.font,
      radii: second.radii,
      spacing: second.spacing,
      motion: second.motion,
      borders: second.borders,
      elevations: MuiElevations.lerp(elevations, other.elevations, t),
      states: second.states,
    );
  }

  /// 主题里没挂 [MuiTokens] 时的兜底 —— 第三方自建 `ThemeData` 的子树会走到这里
  /// （wechat 的 picker、chat_ui 等）。取各 token 表的默认值，不抛异常。
  factory MuiTokens.fallback(Brightness brightness) => MuiTokens(
    onMedia: const Color(0xFFFFFFFF),
    font: const MuiFontConfig(),
    radii: const MuiRadii(),
    spacing: const MuiSpacing(),
    motion: const MuiMotion(),
    borders: const MuiBorders(),
    elevations: MuiElevations.of(brightness),
    states: const MuiStateTokens(),
  );
}
