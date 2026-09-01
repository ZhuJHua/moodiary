import 'package:flutter/services.dart' show PredictiveBackEvent;
import 'package:mui/mui.dart';

/// 选择器的转场：**从下往上入场，从上往下退场**。
///
/// 不用 `MaterialPageRoute(fullscreenDialog: true)` —— 那个在两端给的是不同的
/// 东西（iOS 是自带回弹的模态推入，Android 是淡入加位移），而选择器是从编辑器
/// 底下抽上来的一层，两端应当同一个动作。
///
/// 时长与曲线从 [MuiMotion] 取，但要在**构造时**就定下来（路由的
/// `transitionDuration` 是 getter，取不到 widget 树），所以由调用方喂进来。
class PickerPageRoute<T> extends PageRouteBuilder<T> {
  PickerPageRoute({
    required WidgetBuilder builder,
    required this.motion,
    required this.scrim,
  }) : super(
         pageBuilder: (context, _, _) => builder(context),
         transitionDuration: motion.normal,
         reverseTransitionDuration: motion.normal,
       );

  final MuiMotion motion;

  /// 上一页的压暗色。取 `colors.scrim`，由调用方喂进来（路由构造时取不到 widget 树）。
  final Color scrim;

  /// 遮罩交给 [ModalRoute] 自带的那层 —— 它的不透明度本来就是由**路由 animation**
  /// 驱动的（`ColorTween` 挂在同一个 controller 上），所以手势拖到哪儿它就淡到哪儿，
  /// 不必另铺一层。完全打开时页面自己盖住了全屏，遮罩只在转场与手势期间可见。
  ///
  /// 0.32 是本仓的统一口径（`MSheet.show` 与 `MAlert` 同值），也是 M3 给 scrim 的
  /// 不透明度。**不用框架默认的 `Colors.black54`** —— 那是 material 的历史值，
  /// 且不走色板。
  @override
  Color? get barrierColor => scrim.withValues(alpha: 0.32);

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  /// 与转场同一条规矩：手势驱动时走线性，否则走缓动。不这么做的话，遮罩会和页面
  /// 用两条不同的曲线，拖动时看得出来「暗得比页面快/慢」。
  @override
  Curve get barrierCurve =>
      popGestureInProgress ? Curves.linear : motion.emphasized;

  static final Tween<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 1),
    end: Offset.zero,
  );

  CurvedAnimation? _curved;

  /// 手势驱动时**用线性曲线**：这时 `controller.value` 就是手指的位置，再套一层
  /// 缓动会让页面跑在手指前面或后面。Cupertino 的 `linearTransition` 同理。
  Animation<double> _driveOf(Animation<double> animation) {
    if (popGestureInProgress) return animation;
    final cached = _curved;
    if (cached != null && cached.parent == animation) return cached;
    cached?.dispose();
    return _curved = CurvedAnimation(
      parent: animation,
      curve: motion.emphasized,
      reverseCurve: motion.standard.flipped,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _PredictiveBackHandler(
      route: this,
      child: SlideTransition(
        position: _slide.animate(_driveOf(animation)),
        // 钉在页面自己的矩形上。picker 的相册面板是
        // `AnimatedAlign(alignment: bottomCenter, heightFactor: 0→1)` ——
        // 收起时盒子高度为 0，但子树仍按完整高度布局并绘制，被顶到页面顶边之外。
        // 平时看不见，页面一往下滑（下拉关闭 / 预测性返回）就露出来了。
        child: ClipRect(child: child),
      ),
    );
  }

  /// 框架的 [ModalRoute.handleCommitBackGesture] 在 `navigator.pop()` 之后补了一句
  /// `controller.reverse(from: controller.upperBound)`（`widgets/routes.dart:606`）——
  /// 它把进度**先弹回 1.0** 再倒放。按钮返回时进度本来就是 1，看不出来；手势是从
  /// 当前进度接着走的，拖到接近 0 时就成了「页面滑到底了，又猛地回到顶上重放一遍
  /// 关闭动画」。
  ///
  /// 这里去掉那一句就对了：`pop()` 触发的 `TransitionRoute.didPop` 本来就会调
  /// `reverse()`，而它从当前值倒放、时长按剩余距离自动折算
  /// （`AnimationController._animateToInternal` 的 `remainingFraction`）。
  /// 预测性返回与顶栏下拉都经这里，一处修两处。
  @override
  void handleCommitBackGesture() {
    final controller = this.controller;
    if (controller == null || !isCurrent) {
      super.handleCommitBackGesture();
      return;
    }
    navigator?.pop();
    // `handleStartBackGesture` 配对的 didStartUserGesture 要还回去，且**得等动画
    // 停了再还** —— 期间 popGestureInProgress 仍须为真，转场才继续走线性曲线。
    if (controller.isAnimating) {
      late final AnimationStatusListener listener;
      listener = (status) {
        navigator?.didStopUserGesture();
        controller.removeStatusListener(listener);
      };
      controller.addStatusListener(listener);
    } else {
      navigator?.didStopUserGesture();
    }
  }

  @override
  void dispose() {
    _curved?.dispose();
    _curved = null;
    super.dispose();
  }
}

/// 把 Android 的**预测性返回**接到本路由的动画上。
///
/// 不必自己插值：`TransitionRoute` 实现了 `PredictiveBackRoute`，
/// `handleStartBackGesture` 一族是公开方法，框架收到进度后直接写
/// `controller.value`。所以转场动画一行都不必为手势改 —— 它读的还是同一个
/// animation，自然跟着手指走；松手时 commit / cancel 再把剩下那段补完或退回。
///
/// 只有 `PageTransitionsTheme` 那条路（`MaterialPageRoute`）自带这个探测器，
/// [PageRouteBuilder] 不走那条路，所以这里补一个。
class _PredictiveBackHandler extends StatefulWidget {
  const _PredictiveBackHandler({required this.route, required this.child});

  final PageRoute<dynamic> route;
  final Widget child;

  @override
  State<_PredictiveBackHandler> createState() => _PredictiveBackHandlerState();
}

class _PredictiveBackHandlerState extends State<_PredictiveBackHandler>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 返回 true 表示「这一轮手势我接了」，之后的 update / commit / cancel 才会发
  /// 到这里来。三键返回（`isButtonEvent`）没有进度可跟，让它走默认 pop。
  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    final route = widget.route;
    if (backEvent.isButtonEvent ||
        !route.isCurrent ||
        !route.popGestureEnabled) {
      return false;
    }
    route.handleStartBackGesture(progress: 1 - backEvent.progress);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    widget.route.handleUpdateBackGestureProgress(
      progress: 1 - backEvent.progress,
    );
  }

  @override
  void handleCommitBackGesture() => widget.route.handleCommitBackGesture();

  @override
  void handleCancelBackGesture() => widget.route.handleCancelBackGesture();

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 顶栏下拉关闭。走的是与预测性返回**同一套** `PredictiveBackRoute` 接口，
/// 所以两种来源共用一条动画路径，不存在两套插值。
///
/// iOS 上系统的返回手势是左缘横滑，而这一页是从底下抽上来的模态层 —— 那里的
/// 平台惯例本来就是下拉关闭（系统相册选择、分享面板都是），所以手势轴与转场轴
/// 对齐，不去抢左缘。
class DragDownToDismiss extends StatefulWidget {
  const DragDownToDismiss({super.key, required this.child});

  final Widget child;

  @override
  State<DragDownToDismiss> createState() => _DragDownToDismissState();
}

class _DragDownToDismissState extends State<DragDownToDismiss> {
  ModalRoute<dynamic>? _route;
  double _dragged = 0;
  double _height = 0;

  double get _progress =>
      _height <= 0 ? 1 : (1 - _dragged / _height).clamp(0.0, 1.0);

  void _start(DragStartDetails details) {
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent || !route.popGestureEnabled) return;
    _route = route;
    _dragged = 0;
    _height = MediaQuery.sizeOf(context).height;
    route.handleStartBackGesture(progress: 1);
  }

  void _update(DragUpdateDetails details) {
    final route = _route;
    if (route == null) return;
    _dragged += details.delta.dy;
    route.handleUpdateBackGestureProgress(progress: _progress);
  }

  /// 松手先看甩出去的速度，再看拖过的比例 —— 与官方下拉关闭的判据一致。
  void _end(DragEndDetails details) {
    final route = _route;
    if (route == null) return;
    _route = null;
    final flung = details.velocity.pixelsPerSecond.dy > 700;
    (flung || _progress < 0.5)
        ? route.handleCommitBackGesture()
        : route.handleCancelBackGesture();
  }

  /// 手势被上层抢走时也得把 `didStartUserGesture` 平回来，否则 navigator 的计数
  /// 不归零，之后任何 pop 手势都会被判成「已有手势在进行」。
  void _cancel() {
    final route = _route;
    if (route == null) return;
    _route = null;
    route.handleCancelBackGesture();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: .translucent,
      onVerticalDragStart: _start,
      onVerticalDragUpdate: _update,
      onVerticalDragEnd: _end,
      onVerticalDragCancel: _cancel,
      child: widget.child,
    );
  }
}
