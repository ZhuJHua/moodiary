import 'package:flutter/services.dart' show PredictiveBackEvent;
import 'package:material_ui/material_ui.dart';
import 'package:mui/src/themes/theme.dart';
import 'package:mui/src/themes/tokens.dart';

/// 关闭一层要多久。**按钮返回、系统返回、手势松手后走完整段，三条路径共用它** ——
/// 时长与曲线都一样，看起来才是同一个动作。比推入的 250ms 快一档：退场不需要被看清。
const Duration kMuiCloseDuration = Duration(milliseconds: 220);

/// 收尾时长的下界。只剩一点点距离时别抖一下就没了，留够看得见减速的帧数。
const double _kDropFloorMs = 70;

/// 收尾时长：按剩下这段的长短折算，[distance] 是剩余进度（0..1）。
///
/// 不吃松手速度 —— 系统的预测性返回只给进度不给速度，而它是眼下唯一的手势来源。
Duration muiDropDuration(double distance) {
  final full = kMuiCloseDuration.inMilliseconds.toDouble();
  final ms = (full * distance).clamp(_kDropFloorMs, full);
  return Duration(milliseconds: ms.round());
}

/// 「手势 → 路由动画」的那点账目，所有手势来源共用。
///
/// 拖动期间不必自己插值：`TransitionRoute` 实现了 `PredictiveBackRoute`，
/// `handleStartBackGesture` 一族是公开方法，进度直接写进 controller.value。所以转场
/// 动画一行都不必为手势改 —— 它读的还是同一个 animation，自然跟着手指走。
///
/// 松手之后的**收尾也由这里驱动**，理由见 [_settle]。
///
/// 还有一件事收在这儿：`didStartUserGesture` / `didStopUserGesture` 的配对。
/// 漏一次，navigator 的计数就不归零，之后**任何**手势返回都会被判成「已有手势在
/// 进行」，整个 App 的返回手势永久失效。
class MuiBackGesture {
  MuiBackGesture(
    this.route,
    this.motion,
    TickerProvider vsync, {
    this.renderCurve = Curves.linear,
  }) : _drop = AnimationController(vsync: vsync) {
    _drop
      ..addListener(_tick)
      ..addStatusListener(_onDropEnd);
  }

  final ModalRoute<dynamic> route;

  /// 曲线都从这里取，与转场用的是同一份，不会两边各调各的。
  final MuiMotion motion;

  /// 手势**没接管时**，夹在 controller 的值与屏幕上的位置之间的那条曲线。
  ///
  /// 只在接手的那一刻用：把「此刻屏幕上走到哪」算出来当起点。一旦接管，转场自己会
  /// 切成线性（看 `popGestureInProgress`），写进去多少就是多少。
  final Curve renderCurve;

  /// 收尾曲线，作用在**位移**上。与 [MuiMotion.exitCurve] 是同一条的两种写法：
  /// 那条作用在「页面在不在位」的值上（关闭时 1→0），这条作用在位移上，互为
  /// `flipped`。按钮返回与手势收尾因此严格同形。
  late final Curve _settleCurve = motion.exitCurve.flipped;

  /// 收尾专用。**不是**路由那个 controller —— 那个够不着（`@protected`），
  /// 这个只负责算出进度，再经公开的 `handleUpdateBackGestureProgress` 喂过去。
  final AnimationController _drop;

  bool _active = false;
  bool _dropping = false;
  bool _closing = false;

  /// 这一层此刻在**屏幕上**走到哪：1 = 完全就位，0 = 完全移出。手势从这里接着走，
  /// 而不是从 1 开始。
  ///
  /// **不是 `animation.value`**：接手一次进行中的推入时，若把原始值直接写进去，画面
  /// 会当场跳一下 —— emphasized 前重，`value` 才 0.12 时屏幕上其实已经走了 0.67。
  double get progress {
    final animation = route.animation;
    if (animation == null) return 1;
    if (route.popGestureInProgress) return animation.value;
    return renderCurve.transform(animation.value);
  }

  /// 能不能接手这一轮手势。
  ///
  /// **推入还没走完时也能接**。框架的 `popGestureEnabled` 在这种情况下恒假
  /// （`routes.dart`：「已经在动画里就不能被手势拖」）—— 那条是给官方实现兜底的：
  /// 它们一律 `handleStartBackGesture(progress: 1)`，转场没走完时会把页面猛地顶到
  /// 就位再开始跟手。我们从 [progress] 接着走，没有那一跳，所以这条限制可以掀掉，
  /// 剩下几条守卫（栈底 / 内部消化 pop / `PopScope` 拦截）照原样自己判一遍。
  bool get enabled {
    if (!route.isCurrent) return false;
    if (route.animation?.status == AnimationStatus.forward) {
      return !route.isFirst &&
          !route.willHandlePopInternally &&
          route.popDisposition != RoutePopDisposition.doNotPop;
    }
    return route.popGestureEnabled;
  }

  void start(double screen) {
    // 收尾途中又来一次手势：停掉收尾接着跟手。账目不重开 —— didStartUserGesture
    // 还欠着一次 didStop，再开一次就永远平不了。
    if (_dropping) {
      _drop.stop();
      _dropping = false;
      route.handleUpdateBackGestureProgress(progress: screen);
      return;
    }
    if (_active) return;
    _drop.stop();
    _active = true;
    route.handleStartBackGesture(progress: screen);
  }

  void update(double screen) {
    if (!_active || _dropping) return;
    route.handleUpdateBackGestureProgress(progress: screen);
  }

  void cancel() => _settle(closing: false);

  void commit() => _settle(closing: true);

  /// 松手后把剩下那段补完。
  ///
  /// **不走框架那两条**（`handleCancelBackGesture` / `handleCommitBackGesture`），
  /// 它们最终都落到路由 controller 的 `forward()` / `reverse()`，而那两个是
  /// **线性、且时长按剩余距离折算**的（`_animateToInternal` 的 `remainingFraction`）。
  /// 两个后果叠在一起就是「侧滑关闭又慢又怪」：
  ///
  ///   * 时长按剩余距离折算，于是收尾速度恒为「一整段 / transitionDuration」；
  ///   * 匀速跑到终点直接停，末端没有减速，看起来是「咔」一下顿住。
  ///
  /// 提交那条还额外踩一个坑：`handleCommitBackGesture` 在 `navigator.pop()` 之后补了
  /// `controller.reverse(from: controller.upperBound)`（`widgets/routes.dart`），先把
  /// 进度弹回 1.0 再倒放 —— 拖到接近底了松手，会看到页面猛地跳回原位重放一遍关闭
  /// 动画。那一句是给官方 predictive back 那套「提交后另起一段 400ms」用的。
  ///
  /// 所以这里自己跑一条：曲线走减速，每帧写
  /// `handleUpdateBackGestureProgress`。跑到 0 之后才 `pop()`：那时路由 controller
  /// 已经在 0，`didPop` 里的 `reverse()` 是零时长，`finishedWhenPopped` 当场把路由
  /// 收掉，不会再补一段动画。
  void _settle({required bool closing}) {
    if (!_active || _dropping) return;
    final from = route.animation?.value;
    final target = closing ? 0.0 : 1.0;
    if (from == null || route.navigator == null || from == target) {
      _finish(closing: closing);
      return;
    }
    // 先落座再置位：`value =` 会顺手改状态，from 恰好是 0 / 1 时（比如手一碰就甩、
    // 一次 update 都没有）状态直接变成终态，`_dropping` 若已为真就会当场判定收尾
    // 结束、页面一帧消失。
    _drop.value = from;
    _closing = closing;
    _dropping = true;
    _drop.animateTo(
      target,
      duration: muiDropDuration((target - from).abs()),
      curve: _settleCurve,
    );
  }

  void _tick() {
    if (_dropping) route.handleUpdateBackGestureProgress(progress: _drop.value);
  }

  void _onDropEnd(AnimationStatus status) {
    if (!_dropping || status.isAnimating) return;
    _dropping = false;
    _finish(closing: _closing);
  }

  void _finish({required bool closing}) {
    _active = false;
    _dropping = false;
    final navigator = route.navigator;
    if (closing && navigator != null && route.isCurrent) navigator.pop();
    navigator?.didStopUserGesture();
  }

  /// 手势进行中被拆掉（页面被程序性移除）时平账。晚一帧是为了避开 build 期间改
  /// navigator 状态。
  void abandon() {
    if (!_active) return;
    _active = false;
    _dropping = false;
    _drop.stop();
    final navigator = route.navigator;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator != null && navigator.mounted) {
        navigator.didStopUserGesture();
      }
    });
  }

  void dispose() {
    _drop.dispose();
  }
}

/// 把 Android 的**预测性返回**接到这一层的转场动画上。
///
/// 页面转场自带这套（`MuiPageTransitionsBuilder` 内部就用它）；`showModalBottomSheet`
/// 一类走 `PopupRoute` 的没有 —— 官方只有 `PageTransitionsTheme` 那几个 builder 带
/// 探测器，所以把弹层内容包一层就补上了。
///
/// 非 Android 平台收不到这个事件，挂着等于没挂，不必按平台分叉。
class MPredictiveBack extends StatefulWidget {
  const MPredictiveBack({
    super.key,
    required this.child,
    this.route,
    this.motion,
    this.renderCurve = Curves.linear,
  });

  final Widget child;

  /// 省略则取 `ModalRoute.of(context)`。
  final ModalRoute<dynamic>? route;

  /// 省略则取 `context.theme.motion`。
  final MuiMotion? motion;

  /// 见 [MuiBackGesture.renderCurve]。
  final Curve renderCurve;

  @override
  State<MPredictiveBack> createState() => _MPredictiveBackState();
}

class _MPredictiveBackState extends State<MPredictiveBack>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  MuiBackGesture? _gesture;

  /// 手势开始那一刻这一层在哪。系统给的 `progress` 是 0→1 的比例，要**折算到这段
  /// 剩余行程上**：推入到一半被接手时，从 0.5 往 0 走，而不是先跳到 1。
  double _from = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = widget.route ?? ModalRoute.of<dynamic>(context);
    if (route == null || route == _gesture?.route) return;
    _gesture?.dispose();
    _gesture = MuiBackGesture(
      route,
      widget.motion ?? context.theme.motion,
      this,
      renderCurve: widget.renderCurve,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gesture
      ?..abandon()
      ..dispose();
    super.dispose();
  }

  /// 返回 true 表示「这一轮手势我接了」，之后的 update / commit / cancel 才会发到
  /// 这里来。三键返回（`isButtonEvent`）没有进度可跟，让它走默认 pop。栈里每一层都
  /// 挂着一个探测器，靠 `enabled` 里的 `isCurrent` 把非栈顶那些挡回去。
  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    final gesture = _gesture;
    if (gesture == null || backEvent.isButtonEvent || !gesture.enabled) {
      return false;
    }
    _from = gesture.progress;
    gesture.start(_from * (1 - backEvent.progress));
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) =>
      _gesture?.update(_from * (1 - backEvent.progress));

  @override
  void handleCommitBackGesture() => _gesture?.commit();

  @override
  void handleCancelBackGesture() => _gesture?.cancel();

  @override
  Widget build(BuildContext context) => widget.child;
}
