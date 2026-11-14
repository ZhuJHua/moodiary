part of '../editor.dart';

extension _Handles on TiptapEditorState {
  Widget _handle(int position, {required bool start, required bool collapsed}) {
    final render = _render!;
    final kind = collapsed
        ? _HandleKind.caret
        : start
        ? _HandleKind.start
        : _HandleKind.end;
    final shown = !collapsed || _caretHandleShown || _dragging;
    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: _HandleLayout(render, position, kind, _scroll),
        child: IgnorePointer(
          ignoring: !shown,
          child: AnimatedOpacity(
            opacity: shown ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: _handleGestures(render, position, kind),
          ),
        ),
      ),
    );
  }

  Widget _handleGestures(
    _RenderEditorViewport render,
    int position,
    _HandleKind kind,
  ) {
    final collapsed = kind == _HandleKind.caret,
        start = kind == _HandleKind.start;
    void begin(DragStartDetails details) {
      _touch = true;
      _dragging = true;
      _dragCollapsed = collapsed;
      _hideContextMenu();
      _input.finishComposition();
      _dragAnchor = collapsed
          ? position
          : start
          ? widget.controller.state.selection.to
          : widget.controller.state.selection.from;
      _handleGrab =
          details.globalPosition -
          render.localToGlobal(render.caretRect(position).centerLeft);
      _setState(() => _magnifier = _local(details.globalPosition));
    }

    // The handles live inside the Scrollable and the long-press detector, whose
    // drags pass their slop first; claim the pointer on down instead.
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        _HandleDragRecognizer:
            GestureRecognizerFactoryWithHandlers<_HandleDragRecognizer>(
              _HandleDragRecognizer.new,
              (recognizer) => recognizer
                ..dragStartBehavior = DragStartBehavior.down
                ..onStart = begin
                ..onUpdate = ((details) => _updateDrag(details.globalPosition))
                ..onEnd = (_) {
                  _endDrag(showMenu: true);
                  if (collapsed) _showCaretHandle();
                }
                ..onCancel = () {
                  _endDrag(showMenu: false);
                  if (collapsed) _showCaretHandle();
                },
            ),
      },
      child: CustomPaint(
        key: ValueKey(
          'tiptap-handle-${collapsed
              ? 'caret'
              : start
              ? 'start'
              : 'end'}',
        ),
        painter: _HandlePainter(
          widget.style.handleColor,
          kind,
          render.caretRect(position).height,
        ),
      ),
    );
  }
}

enum _HandleKind { caret, start, end }

const double _ringRadius = 5, _ringGap = 3, _knobRadius = 6;
// How far the caret ring (stroke included) hangs below the line.
const double _handleReach = _ringGap + _ringRadius * 2 + 1;
// The ring's touch box hangs below the line so taps on the text still land.
const Offset _ringCenter = Offset(22, _ringGap + _ringRadius);

// Every handle is a 44 px touch box; range handles centre theirs on the knob.
class _HandleLayout extends SingleChildLayoutDelegate {
  _HandleLayout(
    this.viewport,
    this.position,
    this.kind,
    ScrollController scroll,
  ) : super(relayout: scroll);
  final _RenderEditorViewport viewport;
  final int position;
  final _HandleKind kind;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      const BoxConstraints.tightFor(width: 44, height: 44);
  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // This layout can precede viewport layout in a scroll frame. Project the
    // document caret with that frame's unrestricted raw offset, not a previous
    // widget build's scroll position (and never a clamped in-range offset).
    final shift = Offset(0, viewport.scrollOffset - viewport._offset.pixels);
    final rect =
        (kind == _HandleKind.caret
                ? viewport._visualCaretRect(position)
                : viewport.caretRect(position))
            .shift(shift);
    return switch (kind) {
      _HandleKind.caret => Offset(rect.center.dx - 22, rect.bottom),
      _HandleKind.start => Offset(
        rect.center.dx - 22,
        rect.top - _knobRadius - 22,
      ),
      _HandleKind.end => Offset(
        rect.center.dx - 22,
        rect.bottom + _knobRadius - 22,
      ),
    };
  }

  @override
  // Styling and document layout can change while the selection offsets stay
  // fixed, so a rebuilt handle must refresh its geometry too.
  bool shouldRelayout(_HandleLayout old) => true;
}

class _HandleDragRecognizer extends PanGestureRecognizer {
  _HandleDragRecognizer()
    : super(
        supportedDevices: const {
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
          PointerDeviceKind.trackpad,
        },
      );

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolvePointer(event.pointer, GestureDisposition.accepted);
  }
}

class _HandlePainter extends CustomPainter {
  const _HandlePainter(this.color, this.kind, this.stem);
  final Color color;
  final _HandleKind kind;
  // Line height the range handle's stem spans; it paints past the touch box.
  final double stem;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const center = Offset(22, 22);
    switch (kind) {
      case _HandleKind.caret:
        canvas.drawCircle(
          _ringCenter,
          _ringRadius,
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      case _HandleKind.start:
        canvas.drawRect(Rect.fromLTWH(21, 22, 2, _knobRadius + stem), paint);
        canvas.drawCircle(center, _knobRadius, paint);
      case _HandleKind.end:
        canvas.drawRect(
          Rect.fromLTRB(21, 22 - _knobRadius - stem, 23, 22),
          paint,
        );
        canvas.drawCircle(center, _knobRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_HandlePainter oldDelegate) =>
      color != oldDelegate.color ||
      kind != oldDelegate.kind ||
      stem != oldDelegate.stem;
}

/// Read the notifier during hit testing, before Scrollable's down handler turns
/// a ballistic/drag activity into a hold. Rebuilding an IgnorePointer widget on
/// that notifier would allow a pointer to slip through before the next frame.
class _IgnoreScrollInput extends SingleChildRenderObjectWidget {
  const _IgnoreScrollInput({required this.blocked, required super.child});
  final bool Function() blocked;
  @override
  _RenderIgnoreScrollInput createRenderObject(BuildContext context) =>
      _RenderIgnoreScrollInput(blocked);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderIgnoreScrollInput renderObject,
  ) {
    renderObject.blocked = blocked;
  }
}

class _RenderIgnoreScrollInput extends RenderProxyBox {
  _RenderIgnoreScrollInput(this.blocked);
  bool Function() blocked;
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      !blocked() && super.hitTest(result, position: position);
}

class _Magnifier extends StatefulWidget {
  const _Magnifier({
    required this.point,
    required this.maxWidth,
    required this.style,
  });

  final Offset? point;
  final double? maxWidth;
  final TiptapEditorStyle style;

  @override
  State<_Magnifier> createState() => _MagnifierState();
}

class _MagnifierState extends State<_Magnifier>
    with SingleTickerProviderStateMixin {
  static const _size = Size(108, 54);
  static const _hidden = Positioned(left: 0, top: 0, child: SizedBox.shrink());

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    reverseDuration: const Duration(milliseconds: 110),
  )..addListener(() => setState(() {}));
  Offset? _last;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Magnifier oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.point == null) != (widget.point == null)) _sync();
  }

  void _sync() {
    final target = widget.point == null ? 0.0 : 1.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = target;
    } else if (target == 1) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _last = widget.point ?? _last;
    final point = _last;
    if (point == null || widget.point == null && _controller.isDismissed) {
      return _hidden;
    }
    final t = Curves.easeOutCubic.transform(_controller.value);
    final size = _size * (.6 + .4 * t);
    final left = (point.dx - _size.width / 2).clamp(
      0.0,
      math.max(0.0, (widget.maxWidth ?? _size.width) - _size.width),
    );
    final center = Offset(
      left + _size.width / 2,
      math.max(0.0, point.dy - 90) + _size.height / 2 + (1 - t) * 16,
    );
    final style = widget.style;
    return Positioned(
      left: center.dx - size.width / 2,
      top: center.dy - size.height / 2,
      child: IgnorePointer(
        child: RawMagnifier(
          size: size,
          magnificationScale: 1.35,
          clipBehavior: Clip.antiAlias,
          focalPointOffset: point - center,
          decoration: MagnifierDecoration(
            opacity: t,
            shape: StadiumBorder(
              side: BorderSide(color: style.magnifierBorderColor, width: 2),
            ),
            shadows: [
              BoxShadow(
                color: style.magnifierShadowColor,
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
