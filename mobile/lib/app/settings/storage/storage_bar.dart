import 'dart:math' as math;

import 'package:mui/mui.dart';

/// Retargets each segment and the denominator from their current painted values.
class StorageBar extends StatefulWidget {
  final List<double> values;
  final List<Color> colors;
  final bool scanning;
  const StorageBar({
    super.key,
    required this.values,
    required this.colors,
    required this.scanning,
  });

  @override
  State<StorageBar> createState() => _StorageBarState();
}

class _StorageBarState extends State<StorageBar> with TickerProviderStateMixin {
  late final AnimationController _values = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late List<double> _from = List.filled(widget.values.length + 1, 0);
  late List<double> _to = List.filled(widget.values.length + 1, 0);
  double _scale = 0;
  bool _reduce = false;

  List<double> get _shown {
    final t = _reduce ? 1.0 : Curves.easeOutCubic.transform(_values.value);
    return [
      for (var i = 0; i < _to.length; i++) _from[i] + (_to[i] - _from[i]) * t,
    ];
  }

  void _retarget() {
    _from = _shown;
    final total = widget.values.fold(0.0, (a, b) => a + b);
    _scale = widget.scanning ? math.max(_scale, total * 1.12) : total;
    _to = [...widget.values, _scale];
    if (_reduce) {
      _values.value = 1;
    } else {
      _values.forward(from: 0);
    }
    if (widget.scanning && !_reduce) {
      if (!_sweep.isAnimating) _sweep.repeat();
    } else {
      _sweep.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.disableAnimationsOf(context);
    _retarget();
  }

  @override
  void didUpdateWidget(StorageBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _retarget();
  }

  @override
  void dispose() {
    _values.dispose();
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_values, _sweep]),
    builder: (context, _) {
      final shown = _shown;
      return SizedBox(
        height: 12,
        width: double.infinity,
        child: CustomPaint(
          painter: _StoragePainter(
            values: shown.take(widget.values.length).toList(),
            scale: shown.last,
            colors: widget.colors,
            track: context.theme.colors.surfaceContainerHighest,
            sweep: widget.scanning && !_reduce ? _sweep.value : null,
            light: context.theme.colors.surface,
          ),
        ),
      );
    },
  );
}

class _StoragePainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final double scale;
  final Color track;
  final Color light;
  final double? sweep;
  _StoragePainter({
    required this.values,
    required this.colors,
    required this.scale,
    required this.track,
    required this.light,
    this.sweep,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(bounds, const Radius.circular(6)));
    canvas.drawRect(bounds, Paint()..color = track);
    final total = values.fold(0.0, (a, b) => a + b);
    final denominator = math.max(math.max(scale, total), 1.0);
    final active = values.where((v) => v > 0).length;
    final filled = (total / denominator * size.width).clamp(0.0, size.width);
    final room = math.max(0.0, filled - math.max(0, active - 1) * 2);
    var x = 0.0;
    for (var i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final width = total > 0 ? values[i] / total * room : 0.0;
      final rect = Rect.fromLTWH(x, 0, width, size.height);
      canvas.drawRect(rect, Paint()..color = colors[i]);
      if (sweep != null) {
        final center = (sweep! * 2 - 0.5) * filled;
        final band = Rect.fromLTWH(
          center - filled * 0.3,
          0,
          math.max(1, filled * 0.6),
          size.height,
        );
        canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              colors: [
                light.withValues(alpha: 0),
                light.withValues(alpha: 0.45),
                light.withValues(alpha: 0),
              ],
            ).createShader(band),
        );
      }
      x += width + 2;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StoragePainter oldDelegate) => true;
}
