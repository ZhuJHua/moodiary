import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, listEquals;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as glass;
import 'package:mui/mui.dart';

class MGlassSurface extends StatelessWidget {
  final Widget child;

  final OutlinedBorder shape;

  final Color? tint;

  final Color? borderColor;

  final double? borderWidth;

  final List<BoxShadow>? shadows;

  const MGlassSurface({
    super.key,
    required this.child,
    this.shape = const RoundedRectangleBorder(borderRadius: MuiRadius.lg),
    this.tint,
    this.borderColor,
    this.borderWidth,
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

  static Future<void> initialize() => glass.LiquidGlassWidgets.initialize(
    enablePerformanceMonitor: false,
    warmUpMode: defaultTargetPlatform == TargetPlatform.iOS
        ? glass.GlassWarmUpMode.auto
        : glass.GlassWarmUpMode.never,
  );

  static Widget wrapApp({required Widget child}) =>
      glass.LiquidGlassWidgets.wrap(
        brightnessResolver: (context) => context.theme.colors.brightness,
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final base =
        tint ??
        (scheme.brightness == Brightness.dark
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainer);
    final side = BorderSide(
      color: borderColor ?? scheme.outlineVariant,
      width: borderWidth ?? 1 / MediaQuery.devicePixelRatioOf(context),
    );
    final direction = Directionality.maybeOf(context);
    return CustomPaint(
      painter: _GlassShadowPainter(
        shape: shape,
        textDirection: direction,
        shadows: shadows ?? defaultShadows(scheme),
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: glass.GlassContainer(
          quality: glass.GlassQuality.minimal,
          useOwnLayer: true,
          shape: _liquidShape(direction),
          settings: glass.LiquidGlassSettings(
            glassColor: tint ?? base.withValues(alpha: 0.62),
            bodyMode: glass.GlassBodyMode.clear,
          ),
          child: DecoratedBox(
            decoration: ShapeDecoration(shape: shape.copyWith(side: side)),
            child: child,
          ),
        ),
      ),
    );
  }

  glass.LiquidShape _liquidShape(TextDirection? direction) => switch (shape) {
    StadiumBorder() => const glass.LiquidRoundedRectangle(
      borderRadius: double.infinity,
    ),
    CircleBorder() || OvalBorder() => const glass.LiquidOval(),
    RoundedRectangleBorder(:final borderRadius) => _roundedShape(
      borderRadius.resolve(direction),
    ),
    _ => const glass.LiquidRoundedRectangle(borderRadius: 0),
  };

  glass.LiquidShape _roundedShape(BorderRadius radius) {
    if (radius.topLeft == radius.topRight &&
        radius.bottomLeft == radius.bottomRight &&
        radius.topLeft.x == radius.topLeft.y &&
        radius.bottomLeft.x == radius.bottomLeft.y) {
      return glass.LiquidVerticalRoundedRectangle(
        topRadius: radius.topLeft.x,
        bottomRadius: radius.bottomLeft.x,
      );
    }
    // The outer ClipPath preserves corners the package cannot represent.
    return glass.LiquidRoundedRectangle(
      borderRadius: [
        radius.topLeft.x,
        radius.topLeft.y,
        radius.topRight.x,
        radius.topRight.y,
        radius.bottomLeft.x,
        radius.bottomLeft.y,
        radius.bottomRight.x,
        radius.bottomRight.y,
      ].reduce(math.min),
    );
  }
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
