import 'package:material_ui/material_ui.dart';
import 'package:mui/src/foundation/back_gesture.dart';
import 'package:mui/src/themes/tokens.dart';
import 'package:mui/src/themes/value.dart';

/// 旧页后退的距离，占屏宽的比例。新页整屏推入而旧页只走三分之一，两条速度不同才有
/// 视差。取 Cupertino 的口径。
const double _kParallaxFraction = 1 / 3;

/// scrim 不透明度。0.32 是本仓统一口径（`MSheet.show` / `MAlert` / `PickerPageRoute`
/// 同值），也是 M3 给 scrim 的值。
const double _kScrimOpacity = 0.32;

/// 官方 `FadeForwards` 把新页横移的比例。接手一次进行中的推入时要按它折算。
const double _kFadeForwardsShift = 0.25;

/// Android 的页面转场：**跟手时用我们自己那套，其余一律交给官方的 `FadeForwards`**。
///
/// 判据与 [PredictiveBackPageTransitionsBuilder] 一致 —— 看 `popGestureInProgress`，
/// 而不是查设备支不支持预测性返回（框架没有这个查询）。按钮返回、`go()`、深链这些
/// 没有手势可跟，走官方那条就够；系统不发预测性返回事件的机型（Android 13 以下、
/// 或用户关了手势导航）也自然落到同一条上，不必另判。
///
/// iOS 不用这个 —— 那边的惯例就是 Cupertino 那条推入，边缘返回手势它自带，
/// 见 `buildMuiTheme` 里的 `pageTransitionsTheme`。
///
/// 跟手那套：新页从右整屏推入、旧页做三分之一视差后退并压暗、新页左缘带圆角。
/// 里面**不带任何曲线** —— 手指在哪页面就在哪，松手之后的收尾由 [MuiBackGesture]
/// 自己按松手速度跑（见那边的 `_settle`）。
class MuiPageTransitionsBuilder extends PageTransitionsBuilder with MuiValue {
  MuiPageTransitionsBuilder({
    required this.motion,
    required this.scrim,
    required this.radius,
  });

  final MuiMotion motion;

  /// 旧页的压暗色。取 `colors.scrim` 本体，[_kScrimOpacity] 在内部叠。
  final Color scrim;

  /// 新页左上 / 左下的圆角。
  final double radius;

  /// 非手势那条走官方实现，时长也得跟它对齐，否则 controller 的时长与动画不匹配。
  static const Duration _kDuration = Duration(
    milliseconds: FadeForwardsPageTransitionsBuilder.kTransitionMilliseconds,
  );

  @override
  Duration get transitionDuration => _kDuration;

  @override
  List<Object?> get props => [motion, scrim, radius];

  static final Tween<Offset> _enter = Tween<Offset>(
    begin: const Offset(1, 0),
    end: Offset.zero,
  );

  static final Tween<Offset> _parallax = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(-_kParallaxFraction, 0),
  );

  static final Tween<double> _scrimAlpha = Tween<double>(
    begin: 0,
    end: _kScrimOpacity,
  );

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 探测器挂在**分支之外**：两条转场是两棵不同的子树，切换时里面的 State 全都要
    // 重建，探测器跟着重建就会把进行中的手势丢掉。
    return MPredictiveBack(
      route: route,
      motion: motion,
      // 从推入途中接手时，官方那条正把新页横移四分之一屏；折算成我们这套的进度，
      // 接手那一刻位置才对得上（透明度对不上，见类文档）。
      renderCurve: const _FadeForwardsShift(),
      child: route.popGestureInProgress
          ? _gestureTransition(animation, secondaryAnimation, child)
          : const FadeForwardsPageTransitionsBuilder().buildTransitions(
              route,
              context,
              animation,
              secondaryAnimation,
              child,
            ),
    );
  }

  Widget _gestureTransition(
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: _parallax.animate(secondaryAnimation),
      transformHitTests: false,
      child: SlideTransition(
        position: _enter.animate(animation),
        child: ClipRRect(
          borderRadius: BorderRadius.horizontal(left: Radius.circular(radius)),
          child: _Scrim(
            color: scrim,
            opacity: _scrimAlpha.animate(secondaryAnimation),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 官方 `FadeForwards` 推入到 [transform] 时，新页在屏幕上的横向位置 —— 换算成
/// 「我们这套整屏推入走到了几成」。
///
/// 它的位移是 `0.25 × (1 − 曲线(t))` 个屏宽，我们的是 `1 − 进度`，令两者相等即得。
class _FadeForwardsShift extends Curve {
  const _FadeForwardsShift();

  @override
  double transformInternal(double t) =>
      1 -
      _kFadeForwardsShift * (1 - Curves.easeInOutCubicEmphasized.transform(t));
}

/// 压暗层。画成前景 decoration 而不是 `Stack` 里的一块 —— 前景不参与命中测试，
/// 也就不必再包 `IgnorePointer`。
class _Scrim extends AnimatedWidget {
  const _Scrim({
    required Animation<double> opacity,
    required this.color,
    required this.child,
  }) : super(listenable: opacity);

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final opacity = (listenable as Animation<double>).value;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: opacity <= 0
          ? const BoxDecoration()
          : BoxDecoration(color: color.withValues(alpha: opacity)),
      child: child,
    );
  }
}
