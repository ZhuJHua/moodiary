import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:mui/mui.dart';

class MGlassSurface extends StatelessWidget {
  final Widget child;

  final OutlinedBorder shape;

  final Color? tint;

  final Color? borderColor;

  final List<BoxShadow>? shadows;

  const MGlassSurface({
    super.key,
    required this.child,
    this.shape = const RoundedRectangleBorder(borderRadius: MuiRadius.lg),
    this.tint,
    this.borderColor,
    this.shadows,
  });

  static List<BoxShadow> defaultShadows(ColorScheme colors) => [
    BoxShadow(
      color: colors.shadow.withValues(
        alpha: colors.brightness == Brightness.dark ? 0.42 : 0.12,
      ),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final config = MGlass.of(context);
    final scheme = context.theme.colors;
    final dark = scheme.brightness == .dark;

    final base =
        tint ?? (dark ? scheme.surfaceContainerHigh : scheme.surfaceContainer);
    final fill = base.withValues(alpha: config.tintAlpha);
    final side = BorderSide(
      color:
          borderColor ??
          (dark
              ? scheme.onSurface.withValues(alpha: 0.18)
              : scheme.outlineVariant),
      width: 1 / MediaQuery.devicePixelRatioOf(context),
    );

    return CustomPaint(
      painter: _GlassShadowPainter(
        shape: shape,
        textDirection: Directionality.maybeOf(context),
        shadows: shadows ?? defaultShadows(scheme),
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: BackdropFilter(
          filter: _backdropFilter(config),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: fill,
              shape: shape.copyWith(side: side),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

ImageFilter _backdropFilter(MGlassConfig config) {
  final blur = ImageFilter.blur(
    sigmaX: config.blurSigma,
    sigmaY: config.blurSigma,
  );
  if (config.saturation == 1) return blur;
  return .compose(outer: _saturate(config.saturation), inner: blur);
}

ColorFilter _saturate(double s) {
  const lumR = 0.213, lumG = 0.715, lumB = 0.072;
  return .matrix(<double>[
    lumR + s * (1 - lumR), lumG * (1 - s), lumB * (1 - s), 0, 0,
    lumR * (1 - s), lumG + s * (1 - lumG), lumB * (1 - s), 0, 0,
    lumR * (1 - s), lumG * (1 - s), lumB + s * (1 - lumB), 0, 0,
    0, 0, 0, 1, 0,
  ]);
}

class _GlassShadowPainter extends CustomPainter {
  final OutlinedBorder shape;
  final List<BoxShadow> shadows;
  final TextDirection? textDirection;

  const _GlassShadowPainter({
    required this.shape,
    required this.shadows,
    this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (shadows.isEmpty) return;
    final rect = Offset.zero & size;
    final body = shape.getOuterPath(rect, textDirection: textDirection);

    var reach = 0.0;
    for (final shadow in shadows) {
      reach = math.max(
        reach,
        3 * shadow.blurSigma + shadow.spreadRadius + shadow.offset.distance,
      );
    }
    canvas.save();
    canvas.clipPath(
      .combine(.difference, Path()..addRect(rect.inflate(reach + 1)), body),
    );
    for (final shadow in shadows) {
      canvas.drawPath(
        shape.getOuterPath(
          rect.shift(shadow.offset).inflate(shadow.spreadRadius),
          textDirection: textDirection,
        ),
        shadow.toPaint(),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassShadowPainter oldDelegate) =>
      oldDelegate.shape != shape ||
      oldDelegate.textDirection != textDirection ||
      !listEquals(oldDelegate.shadows, shadows);
}
