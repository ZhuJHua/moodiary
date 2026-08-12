import 'package:flutter/widgets.dart';
import 'package:mui/src/themes/value.dart';

/// 按交互状态取色的不可变值对象。**主题字段一律用它，不用 `WidgetStateProperty`。**
///
/// `WidgetStateProperty.resolveWith` 持有闭包，`==` 是闭包身份比较 —— 两次结构相同的
/// 构造永不相等。一旦它进了主题字段，`MuiThemeData.==` 就恒为 false，
/// `MuiTheme` 每次重建都通知全部依赖点、`MuiAnimatedTheme` 每帧重启补间。
/// 这里换成纯字段比较，从结构上堵死。
///
/// `WidgetState` / `WidgetStatesController` 本身照用（它们在 widgets 层），
/// 只是不进主题字段。
@immutable
class MuiStateColors with MuiValue {
  const MuiStateColors({
    this.normal,
    this.hovered,
    this.pressed,
    this.focused,
    this.disabled,
    this.selected,
  });

  final Color? normal;
  final Color? hovered;
  final Color? pressed;
  final Color? focused;
  final Color? disabled;
  final Color? selected;

  @override
  List<Object?> get props => [
    normal,
    hovered,
    pressed,
    focused,
    disabled,
    selected,
  ];

  /// 优先级：disabled > pressed > hovered > focused > selected > normal。
  ///
  /// disabled 必须排第一 —— 禁用态下同时挂着 hovered 是常见组合，反过来会让禁用
  /// 控件画成可点的样子。
  Color resolve(Set<WidgetState> states, {required Color fallback}) {
    if (states.contains(WidgetState.disabled)) {
      return disabled ?? normal ?? fallback;
    }
    if (states.contains(WidgetState.pressed)) {
      return pressed ?? normal ?? fallback;
    }
    if (states.contains(WidgetState.hovered)) {
      return hovered ?? normal ?? fallback;
    }
    if (states.contains(WidgetState.focused)) {
      return focused ?? normal ?? fallback;
    }
    if (states.contains(WidgetState.selected)) {
      return selected ?? normal ?? fallback;
    }
    return normal ?? fallback;
  }

  MuiStateColors merge(MuiStateColors? other) => other == null
      ? this
      : MuiStateColors(
          normal: other.normal ?? normal,
          hovered: other.hovered ?? hovered,
          pressed: other.pressed ?? pressed,
          focused: other.focused ?? focused,
          disabled: other.disabled ?? disabled,
          selected: other.selected ?? selected,
        );

  static MuiStateColors? lerp(MuiStateColors? a, MuiStateColors? b, double t) =>
      a == null && b == null
      ? null
      : MuiStateColors(
          normal: Color.lerp(a?.normal, b?.normal, t),
          hovered: Color.lerp(a?.hovered, b?.hovered, t),
          pressed: Color.lerp(a?.pressed, b?.pressed, t),
          focused: Color.lerp(a?.focused, b?.focused, t),
          disabled: Color.lerp(a?.disabled, b?.disabled, t),
          selected: Color.lerp(a?.selected, b?.selected, t),
        );
}
