import 'package:flutter/services.dart' show PredictiveBackEvent;
import 'package:material_ui/material_ui.dart';
import 'package:mui/src/themes/theme.dart';
import 'package:mui/src/themes/tokens.dart';

const Duration kMuiCloseDuration = Duration(milliseconds: 220);

const double _kDropFloorMs = 70;

Duration muiDropDuration(double distance) {
  final full = kMuiCloseDuration.inMilliseconds.toDouble();
  final ms = (full * distance).clamp(_kDropFloorMs, full);
  return Duration(milliseconds: ms.round());
}

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

  final MuiMotion motion;

  final Curve renderCurve;

  late final Curve _settleCurve = motion.exitCurve.flipped;

  final AnimationController _drop;

  bool _active = false;
  bool _dropping = false;
  bool _closing = false;

  double get progress {
    final animation = route.animation;
    if (animation == null) return 1;
    if (route.popGestureInProgress) return animation.value;
    return renderCurve.transform(animation.value);
  }

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

  void _settle({required bool closing}) {
    if (!_active || _dropping) return;
    final from = route.animation?.value;
    final target = closing ? 0.0 : 1.0;
    if (from == null || route.navigator == null || from == target) {
      _finish(closing: closing);
      return;
    }
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

class MPredictiveBack extends StatefulWidget {
  const MPredictiveBack({
    super.key,
    required this.child,
    this.route,
    this.motion,
    this.renderCurve = Curves.linear,
  });

  final Widget child;

  final ModalRoute<dynamic>? route;

  final MuiMotion? motion;

  final Curve renderCurve;

  @override
  State<MPredictiveBack> createState() => _MPredictiveBackState();
}

class _MPredictiveBackState extends State<MPredictiveBack>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  MuiBackGesture? _gesture;

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
