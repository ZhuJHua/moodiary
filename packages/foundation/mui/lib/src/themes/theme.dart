import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mui/src/themes/theme_data.dart';

/// 主题注入点。
///
/// 内部是 [InheritedTheme] 而非普通 `InheritedWidget`：本仓有 alert / menu / sheet /
/// toast 四套自实现浮层，它们跨 `Overlay` 边界重建子树，只有 [InheritedTheme.capture]
/// 能把主题一起带过去。
class MuiTheme extends StatelessWidget {
  const MuiTheme({super.key, required this.data, required this.child});

  final MuiThemeData data;
  final Widget child;

  /// 组件内部取主题的唯一写法。找不到就抛 —— 静默回落到某份默认主题只会让
  /// 「为什么这一块配色不对」变成一场考古。
  static MuiThemeData of(BuildContext context) {
    final data = maybeOf(context);
    if (data == null) {
      throw FlutterError.fromParts([
        ErrorSummary('找不到 MuiTheme。'),
        ErrorDescription('${context.widget.runtimeType} 所在的子树里没有 MuiTheme 祖先。'),
        ErrorHint('在应用根部包一层 MuiTheme 或 MuiAnimatedTheme。'),
        context.describeElement('触发查找的 widget'),
      ]);
    }
    return data;
  }

  /// [listen] 为 false 时不建立依赖，供 `initState` 与回调里取值用。
  static MuiThemeData? maybeOf(BuildContext context, {bool listen = true}) {
    if (listen) {
      return context
          .dependOnInheritedWidgetOfExactType<_MuiInheritedTheme>()
          ?.data;
    }
    final element = context
        .getElementForInheritedWidgetOfExactType<_MuiInheritedTheme>();
    return (element?.widget as _MuiInheritedTheme?)?.data;
  }

  /// 子树局部覆盖。[apply] 的产物应可缓存，别写在每帧 build 里。
  static Widget merge({
    Key? key,
    required MuiThemeData Function(MuiThemeData parent) apply,
    required Widget child,
  }) => Builder(
    key: key,
    builder: (context) => MuiTheme(data: apply(of(context)), child: child),
  );

  @override
  Widget build(BuildContext context) =>
      _MuiInheritedTheme(theme: this, child: child);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<Brightness>('brightness', data.brightness),
    );
  }
}

class _MuiInheritedTheme extends InheritedTheme {
  const _MuiInheritedTheme({required this.theme, required super.child});

  final MuiTheme theme;

  MuiThemeData get data => theme.data;

  @override
  Widget wrap(BuildContext context, Widget child) =>
      MuiTheme(data: theme.data, child: child);

  @override
  bool updateShouldNotify(_MuiInheritedTheme oldWidget) =>
      theme.data != oldWidget.theme.data;
}

class MuiThemeDataTween extends Tween<MuiThemeData> {
  MuiThemeDataTween({super.begin, super.end});

  @override
  MuiThemeData lerp(double t) => MuiThemeData.lerp(begin!, end!, t);
}

/// 带补间的主题注入。深浅色与三态配色切换会平滑过渡 —— 这是 `MaterialApp` 现在
/// 免费提供的行为，不做即为可见回归。
///
/// 时长取 `data.motion.themeSwitch`，**必须与 material 侧 `kThemeChangeDuration`
/// 一致**：共存期同屏两套子树，时长不同会看到一边渐变一边已经跳完。
///
/// 挂载位置有唯一正确答案：放在 `WidgetsApp` / `MaterialApp` 的 `builder` 内、
/// 且在浮层宿主（`FlutterSmartDialog.init()`）**外面** —— 那个 init 会自建 Overlay，
/// toast 与 loading 是与 child 平级的兄弟 entry，包在里面它们吃不到主题。
class MuiAnimatedTheme extends ImplicitlyAnimatedWidget {
  MuiAnimatedTheme({
    super.key,
    required this.data,
    super.curve,
    Duration? duration,
    super.onEnd,
    required this.child,
  }) : super(duration: duration ?? data.motion.themeSwitch);

  final MuiThemeData data;
  final Widget child;

  @override
  AnimatedWidgetBaseState<MuiAnimatedTheme> createState() =>
      _MuiAnimatedThemeState();
}

class _MuiAnimatedThemeState extends AnimatedWidgetBaseState<MuiAnimatedTheme> {
  MuiThemeDataTween? _data;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _data =
        visitor(
              _data,
              widget.data,
              (value) => MuiThemeDataTween(begin: value as MuiThemeData),
            )
            as MuiThemeDataTween?;
  }

  @override
  Widget build(BuildContext context) =>
      MuiTheme(data: _data!.evaluate(animation), child: widget.child);
}

extension MuiThemeContext on BuildContext {
  /// mui 主题的取用入口。
  ///
  /// `theme` 这个名字已经从 `moodiary_utils/theme_ext.dart` 让出来了（那边只留
  /// 共存期还要用的 `colorScheme` / `textTheme` / `isDarkMode`，返回 material 类型），
  /// 所以两边同时 import 也不歧义。
  ///
  /// 新代码的写法：`context.theme.typography.title1.onSurfaceVariant`。
  MuiThemeData get theme => MuiTheme.of(this);
}
