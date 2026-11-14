part of '../editor.dart';

// A separate repaint listenable keeps cursor frames out of document painting.
class _CaretMotion extends ChangeNotifier {
  _CaretMotion(TickerProvider vsync) {
    _ticker = vsync.createTicker(_tick);
  }
  late final Ticker _ticker;
  int _lastElapsed = 0;
  bool enabled = false, reduced = false;
  Rect? rect, _from, _target;
  double opacity = 0;
  int _idle = 0, _movement = 100;
  bool get running => _ticker.isActive;

  void _tick(Duration elapsed) {
    final oldOpacity = opacity, oldRect = rect;
    final delta = elapsed.inMilliseconds - _lastElapsed;
    _lastElapsed = elapsed.inMilliseconds;
    _idle += delta;
    if (_idle > 500) {
      final phase = ((_idle - 500) % 1000) / 500;
      opacity = reduced
          ? (phase < 1 ? 1 : 0)
          : (phase < 1
                ? 1 - Curves.easeInOut.transform(phase)
                : Curves.easeInOut.transform(phase - 1));
    }
    if (_movement < 100) {
      _movement = math.min(100, _movement + delta);
      rect = Rect.lerp(
        _from,
        _target,
        Curves.easeOut.transform(_movement / 100),
      );
    }
    if (opacity != oldOpacity || rect != oldRect) notifyListeners();
  }

  void enable(bool value, {required bool reduced}) {
    this.reduced = reduced;
    if (enabled == value) return;
    enabled = value;
    _ticker.stop();
    opacity = value ? 1 : 0;
    if (value) {
      _lastElapsed = 0;
      _ticker.start();
    }
    notifyListeners();
  }

  void activity() {
    _idle = 0;
    if (enabled) opacity = 1;
    notifyListeners();
  }

  void move(Rect target, Size viewport, {required bool snap}) {
    if (_target == target) {
      if (snap && rect != target) {
        rect = target;
        _movement = 100;
        notifyListeners();
      }
      return;
    }
    final bounds = Offset.zero & viewport;
    final old = rect;
    final animate =
        enabled &&
        !snap &&
        old != null &&
        bounds.contains(old.topLeft) &&
        bounds.contains(old.bottomRight) &&
        bounds.contains(target.topLeft) &&
        bounds.contains(target.bottomRight) &&
        (target.center - old.center).distance <= viewport.height;
    _from = old;
    _target = target;
    _movement = animate ? 0 : 100;
    if (!animate) rect = target;
    activity();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

class _CaretPainter extends CustomPainter {
  _CaretPainter(this.motion, this.style, this.dpr) : super(repaint: motion);
  final _CaretMotion motion;
  final TiptapEditorStyle style;
  final double dpr;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = motion.rect;
    if (!motion.enabled || rect == null || motion.opacity == 0) return;
    double pixel(double n) => (n * dpr).roundToDouble() / dpr;
    final snapped = Rect.fromLTRB(
      pixel(rect.left),
      pixel(rect.top),
      pixel(rect.right),
      pixel(rect.bottom),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(snapped, Radius.circular(style.caretRadius)),
      Paint()
        ..color = style.caretColor.withValues(
          alpha: style.caretColor.a * motion.opacity,
        ),
    );
  }

  @override
  bool shouldRepaint(_CaretPainter old) =>
      old.style != style || old.dpr != dpr || old.motion != motion;
}
