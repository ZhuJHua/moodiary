import 'package:flutter/services.dart' show PredictiveBackEvent;
import 'package:mui/mui.dart';

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

  final Color scrim;

  @override
  Color? get barrierColor => scrim.withValues(alpha: 0.32);

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  Curve get barrierCurve =>
      popGestureInProgress ? Curves.linear : motion.emphasized;

  static final Tween<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 1),
    end: Offset.zero,
  );

  CurvedAnimation? _curved;

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
        child: ClipRect(child: child),
      ),
    );
  }

  @override
  void handleCommitBackGesture() {
    final controller = this.controller;
    if (controller == null || !isCurrent) {
      super.handleCommitBackGesture();
      return;
    }
    navigator?.pop();
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

  void _end(DragEndDetails details) {
    final route = _route;
    if (route == null) return;
    _route = null;
    final flung = details.velocity.pixelsPerSecond.dy > 700;
    (flung || _progress < 0.5)
        ? route.handleCommitBackGesture()
        : route.handleCancelBackGesture();
  }

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
