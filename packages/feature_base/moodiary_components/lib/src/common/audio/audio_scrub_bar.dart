import 'dart:math' as math;

import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

class MAudioScrubBar extends StatefulWidget {
  final double fraction;
  final ValueChanged<double> onSeek;

  const MAudioScrubBar({
    super.key,
    required this.fraction,
    required this.onSeek,
  });

  @override
  State<MAudioScrubBar> createState() => _MAudioScrubBarState();
}

class _MAudioScrubBarState extends State<MAudioScrubBar> {
  double? _draft;

  double _fraction(Offset local) =>
      (local.dx / context.size!.width).clamp(0, 1);

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final fraction = _draft ?? widget.fraction;
    return Semantics(
      label: context.l10n.ui.playbackProgress,
      value: '${(fraction * 100).round()}%',
      child: GestureDetector(
        behavior: .opaque,
        onTapUp: (details) => widget.onSeek(_fraction(details.localPosition)),
        onHorizontalDragStart: (details) =>
            setState(() => _draft = _fraction(details.localPosition)),
        onHorizontalDragUpdate: (details) =>
            setState(() => _draft = _fraction(details.localPosition)),
        onHorizontalDragCancel: () => setState(() => _draft = null),
        onHorizontalDragEnd: (_) {
          final target = _draft;
          setState(() => _draft = null);
          if (target != null) widget.onSeek(target);
        },
        child: SizedBox(
          height: 44,
          child: Center(
            child: CustomPaint(
              size: Size(double.infinity, _draft == null ? 3 : 6),
              painter: _ScrubPainter(
                fraction: fraction,
                track: colors.surfaceContainerHighest,
                fill: colors.primary,
                thumbRadius: _draft == null ? 5 : 7,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScrubPainter extends CustomPainter {
  final double fraction;
  final Color track;
  final Color fill;
  final double thumbRadius;

  _ScrubPainter({
    required this.fraction,
    required this.track,
    required this.fill,
    required this.thumbRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = track,
    );
    final w = math.max(size.width * fraction, size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, size.height), radius),
      Paint()..color = fill,
    );
    canvas.drawCircle(
      Offset(size.width * fraction, size.height / 2),
      thumbRadius,
      Paint()..color = fill,
    );
  }

  @override
  bool shouldRepaint(covariant _ScrubPainter old) =>
      old.fraction != fraction ||
      old.track != track ||
      old.fill != fill ||
      old.thumbRadius != thumbRadius;
}
