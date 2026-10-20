import 'dart:async';

import 'package:mui/mui.dart';

const Duration _kMinPressed = Duration(milliseconds: 100);

const Duration _kReleaseFade = Duration(milliseconds: 150);

abstract class _MInkWellPressedHost {
  void onDescendantPressedChanged(bool pressed);
}

class _MInkWellScope extends InheritedWidget {
  const _MInkWellScope({required this.host, required super.child});

  final _MInkWellPressedHost host;

  static _MInkWellPressedHost? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_MInkWellScope>()?.host;

  @override
  bool updateShouldNotify(_MInkWellScope oldWidget) =>
      !identical(host, oldWidget.host);
}

class MInkWell extends StatefulWidget {
  final Widget child;

  final GestureTapCallback? onTap;
  final GestureLongPressCallback? onLongPress;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressUpCallback? onLongPressUp;

  final HitTestBehavior? behavior;

  final BorderRadiusGeometry? borderRadius;
  final ShapeBorder? shape;

  final bool enabled;

  final Color? overlayColor;

  final bool _fade;

  const MInkWell({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onLongPressStart,
    this.onLongPressUp,
    this.behavior,
    this.borderRadius,
    this.shape,
    this.enabled = true,
    this.overlayColor,
  }) : _fade = false,
       assert(
         borderRadius == null || shape == null,
         'borderRadius 与 shape 只能给一个。',
       );

  const MInkWell.fade({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onLongPressStart,
    this.onLongPressUp,
    this.behavior,
    this.enabled = true,
  }) : _fade = true,
       borderRadius = null,
       shape = null,
       overlayColor = null;

  @override
  State<MInkWell> createState() => _MInkWellState();
}

class _MInkWellState extends State<MInkWell>
    with SingleTickerProviderStateMixin
    implements _MInkWellPressedHost {
  bool _selfPressed = false;
  int _pressedDescendants = 0;

  Timer? _minPressedTimer;
  bool _releasePending = false;
  bool _voided = false;

  late final AnimationController _feedback = AnimationController(vsync: this);

  _MInkWellPressedHost? _parent;

  bool get _isInteractive =>
      widget.onTap != null ||
      widget.onLongPress != null ||
      widget.onLongPressStart != null ||
      widget.onLongPressUp != null;

  bool get _isPressedAnywhere => _selfPressed || _pressedDescendants > 0;

  bool get _shouldRenderPressed =>
      widget.enabled && _selfPressed && _pressedDescendants == 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = _MInkWellScope.maybeOf(context);
    if (identical(next, _parent)) return;
    final reporting = _isPressedAnywhere;
    if (reporting) _parent?.onDescendantPressedChanged(false);
    _parent = next;
    if (reporting) _parent?.onDescendantPressedChanged(true);
  }

  @override
  void didUpdateWidget(covariant MInkWell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _selfPressed) {
      _voided = true;
      _release();
    }
    _syncFeedback();
  }

  @override
  void dispose() {
    _minPressedTimer?.cancel();
    if (_isPressedAnywhere) _parent?.onDescendantPressedChanged(false);
    _feedback.dispose();
    super.dispose();
  }

  @override
  void onDescendantPressedChanged(bool pressed) {
    if (!mounted) return;
    final was = _isPressedAnywhere;
    _pressedDescendants += pressed ? 1 : -1;
    assert(_pressedDescendants >= 0, 'MInkWell 的子树按压计数被减穿了');
    if (_shouldRenderPressed) {
      scheduleMicrotask(() {
        if (mounted) _syncFeedback();
      });
    } else {
      _syncFeedback();
    }
    if (was != _isPressedAnywhere) {
      _parent?.onDescendantPressedChanged(_isPressedAnywhere);
    }
  }

  void _setPressed(bool value) {
    if (!mounted || _selfPressed == value) return;
    final was = _isPressedAnywhere;
    _selfPressed = value;
    _syncFeedback();
    if (was != _isPressedAnywhere) {
      _parent?.onDescendantPressedChanged(_isPressedAnywhere);
    }
  }

  void _syncFeedback() {
    if (_shouldRenderPressed) {
      _feedback.value = 1;
    } else if (_selfPressed || _pressedDescendants > 0 || !widget.enabled) {
      _feedback.value = 0;
    } else if (_feedback.value > 0 && !_feedback.isAnimating) {
      unawaited(
        _feedback.animateTo(0, duration: _kReleaseFade, curve: Curves.easeOut),
      );
    }
  }

  bool get _armed => widget.enabled && !_voided;

  void _startHold() {
    _minPressedTimer?.cancel();
    _minPressedTimer = Timer(_kMinPressed, () {
      if (_releasePending) _setPressed(false);
      _releasePending = false;
    });
  }

  void _scheduleRelease() {
    final held = _minPressedTimer?.isActive ?? false;
    if (!held && _armed && _feedback.value == 0) _startHold();
    if (_minPressedTimer?.isActive ?? false) {
      _releasePending = true;
    } else {
      _setPressed(false);
    }
  }

  void _press() {
    _voided = false;
    _releasePending = false;
    _startHold();
    _setPressed(true);
  }

  void _release() {
    _minPressedTimer?.cancel();
    _releasePending = false;
    _setPressed(false);
  }

  void _onTap() {
    if (_armed) widget.onTap?.call();
    _scheduleRelease();
  }

  void _onLongPress() {
    if (_armed) widget.onLongPress?.call();
    _release();
  }

  void _onLongPressStart(LongPressStartDetails details) {
    if (_armed) widget.onLongPressStart?.call(details);
    _release();
  }

  Widget _withFeedback(Widget child) {
    final states = context.theme.states;
    if (widget._fade) {
      return FadeTransition(
        opacity: _feedback.drive(
          Tween(begin: 1, end: states.pressedContentOpacity),
        ),
        child: child,
      );
    }
    final scheme = context.theme.colors;
    final color =
        widget.overlayColor ??
        scheme.onSurface.withValues(alpha: states.pressedOpacity);
    return Stack(
      fit: .passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: FadeTransition(
              opacity: _feedback,
              child: ColoredBox(color: color),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final behavior = widget.behavior ?? HitTestBehavior.opaque;
    Widget result = _withFeedback(widget.child);

    final hasTap = widget.onTap != null;
    final hasLongPress =
        widget.onLongPress != null ||
        widget.onLongPressStart != null ||
        widget.onLongPressUp != null;
    result = IgnorePointer(
      ignoring: _isInteractive && !widget.enabled,
      child: GestureDetector(
        behavior: _isInteractive ? behavior : HitTestBehavior.deferToChild,
        onTapDown: hasTap ? (_) => _press() : null,
        onTap: hasTap ? _onTap : null,
        onTapCancel: hasTap ? _release : null,
        onLongPressDown: hasLongPress && !hasTap ? (_) => _press() : null,
        onLongPress: widget.onLongPress != null ? _onLongPress : null,
        onLongPressStart: hasLongPress ? _onLongPressStart : null,
        onLongPressUp: widget.onLongPressUp == null
            ? null
            : () {
                if (_armed) widget.onLongPressUp!();
              },
        onLongPressCancel: hasLongPress && !hasTap ? _release : null,
        child: result,
      ),
    );

    final borderRadius = widget.borderRadius;
    final shape = widget.shape;
    if (borderRadius != null) {
      result = ClipRRect(borderRadius: borderRadius, child: result);
    } else if (shape != null) {
      result = ClipPath(
        clipper: ShapeBorderClipper(
          shape: shape,
          textDirection: Directionality.maybeOf(context),
        ),
        child: result,
      );
    }

    return _MInkWellScope(host: this, child: result);
  }
}
