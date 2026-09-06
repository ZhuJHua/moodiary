import 'dart:async';

import 'package:mui/mui.dart';

const Duration _kReleaseDelay = Duration(milliseconds: 50);

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
  }) : assert(
         borderRadius == null || shape == null,
         'borderRadius 与 shape 只能给一个。',
       );

  @override
  State<MInkWell> createState() => _MInkWellState();
}

class _MInkWellState extends State<MInkWell> implements _MInkWellPressedHost {
  bool _selfPressed = false;
  int _pressedDescendants = 0;

  Timer? _releaseTimer;

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
    if (!widget.enabled && _selfPressed) _setPressed(false);
  }

  @override
  void dispose() {
    _releaseTimer?.cancel();
    if (_isPressedAnywhere) _parent?.onDescendantPressedChanged(false);
    super.dispose();
  }

  @override
  void onDescendantPressedChanged(bool pressed) {
    if (!mounted) return;
    final was = _isPressedAnywhere;
    setState(() {
      _pressedDescendants += pressed ? 1 : -1;
      assert(_pressedDescendants >= 0, 'MInkWell 的子树按压计数被减穿了');
    });
    if (was != _isPressedAnywhere) {
      _parent?.onDescendantPressedChanged(_isPressedAnywhere);
    }
  }

  void _setPressed(bool value) {
    if (!mounted || _selfPressed == value) return;
    final was = _isPressedAnywhere;
    setState(() => _selfPressed = value);
    if (was != _isPressedAnywhere) {
      _parent?.onDescendantPressedChanged(_isPressedAnywhere);
    }
  }

  void _scheduleRelease() {
    if (!_selfPressed) return;
    _releaseTimer?.cancel();
    _releaseTimer = Timer(_kReleaseDelay, () {
      _releaseTimer = null;
      _setPressed(false);
    });
  }

  void _cancelRelease() {
    _releaseTimer?.cancel();
    _releaseTimer = null;
  }

  void _press() {
    _cancelRelease();
    _setPressed(true);
  }

  void _release() {
    _cancelRelease();
    _setPressed(false);
  }

  void _onTap() {
    widget.onTap?.call();
    _scheduleRelease();
  }

  void _onLongPress() {
    widget.onLongPress?.call();
    _release();
  }

  void _onLongPressStart(LongPressStartDetails details) {
    widget.onLongPressStart?.call(details);
    _release();
  }

  Widget _withOverlay(Widget child) {
    final scheme = context.theme.colors;
    final color =
        widget.overlayColor ??
        scheme.onSurface.withValues(alpha: context.theme.states.pressedOpacity);
    return Stack(
      fit: .passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(
              color: _shouldRenderPressed ? color : Colors.transparent,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final behavior = widget.behavior ?? HitTestBehavior.opaque;
    Widget result = _withOverlay(widget.child);

    if (_isInteractive) {
      final hasTap = widget.onTap != null;
      final hasLongPress =
          widget.onLongPress != null ||
          widget.onLongPressStart != null ||
          widget.onLongPressUp != null;
      result = GestureDetector(
        behavior: behavior,
        onTapDown: hasTap ? (_) => _press() : null,
        onTap: hasTap ? _onTap : null,
        onTapCancel: hasTap ? _release : null,
        onLongPressDown: hasLongPress && !hasTap ? (_) => _press() : null,
        onLongPress: widget.onLongPress != null ? _onLongPress : null,
        onLongPressStart: hasLongPress ? _onLongPressStart : null,
        onLongPressUp: widget.onLongPressUp,
        onLongPressCancel: hasLongPress ? _release : null,
        child: result,
      );
      if (!widget.enabled) result = IgnorePointer(child: result);
    }

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
