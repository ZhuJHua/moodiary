import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';
import 'package:mui/src/themes/value.dart';

@immutable
class MuiRadii with MuiValue {
  const MuiRadii({
    this.sm = 8,
    this.md = 12,
    this.lg = 16,
    this.xl = 24,
    this.full = 999,
  });

  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double full;

  @override
  List<Object?> get props => [sm, md, lg, xl, full];

  static MuiRadii lerp(MuiRadii a, MuiRadii b, double t) => MuiRadii(
    sm: lerpDouble(a.sm, b.sm, t)!,
    md: lerpDouble(a.md, b.md, t)!,
    lg: lerpDouble(a.lg, b.lg, t)!,
    xl: lerpDouble(a.xl, b.xl, t)!,
    full: lerpDouble(a.full, b.full, t)!,
  );
}

@immutable
class MuiSpacing with MuiValue {
  const MuiSpacing({
    this.xs = 4,
    this.sm = 8,
    this.md = 12,
    this.lg = 16,
    this.xl = 24,
    this.pagePadding = const .symmetric(horizontal: 16),
    this.minTapTarget = 48,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final EdgeInsets pagePadding;
  final double minTapTarget;

  @override
  List<Object?> get props => [xs, sm, md, lg, xl, pagePadding, minTapTarget];

  static MuiSpacing lerp(MuiSpacing a, MuiSpacing b, double t) => MuiSpacing(
    xs: lerpDouble(a.xs, b.xs, t)!,
    sm: lerpDouble(a.sm, b.sm, t)!,
    md: lerpDouble(a.md, b.md, t)!,
    lg: lerpDouble(a.lg, b.lg, t)!,
    xl: lerpDouble(a.xl, b.xl, t)!,
    pagePadding: EdgeInsets.lerp(a.pagePadding, b.pagePadding, t)!,
    minTapTarget: lerpDouble(a.minTapTarget, b.minTapTarget, t)!,
  );
}

@immutable
class MuiMotion with MuiValue {
  const MuiMotion({
    this.fast = const Duration(milliseconds: 150),
    this.normal = const Duration(milliseconds: 250),
    this.slow = const Duration(milliseconds: 400),
    this.enter = const Duration(milliseconds: 200),
    this.exit = const Duration(milliseconds: 130),
    this.themeSwitch = const Duration(milliseconds: 200),
    this.standard = const Cubic(0.2, 0, 0, 1),
    this.emphasized = const Cubic(0.05, 0.7, 0.1, 1),
    this.enterCurve = Curves.easeOutCubic,
    this.exitCurve = Curves.easeInCubic,
  });

  final Duration fast;
  final Duration normal;
  final Duration slow;
  final Duration enter;
  final Duration exit;

  final Duration themeSwitch;

  final Curve standard;
  final Curve emphasized;
  final Curve enterCurve;
  final Curve exitCurve;

  @override
  List<Object?> get props => [
    fast,
    normal,
    slow,
    enter,
    exit,
    themeSwitch,
    standard,
    emphasized,
    enterCurve,
    exitCurve,
  ];

  static MuiMotion lerp(MuiMotion a, MuiMotion b, double t) => t < 0.5 ? a : b;
}

@immutable
class MuiBorders with MuiValue {
  const MuiBorders({
    this.hairline = 0.5,
    this.thin = 1,
    this.ring = 1.5,
    this.ringOffset = 3,
  });

  final double hairline;

  final double thin;

  final double ring;

  final double ringOffset;

  @override
  List<Object?> get props => [hairline, thin, ring, ringOffset];

  static MuiBorders lerp(MuiBorders a, MuiBorders b, double t) => MuiBorders(
    hairline: lerpDouble(a.hairline, b.hairline, t)!,
    thin: lerpDouble(a.thin, b.thin, t)!,
    ring: lerpDouble(a.ring, b.ring, t)!,
    ringOffset: lerpDouble(a.ringOffset, b.ringOffset, t)!,
  );
}

@immutable
class MuiElevations with MuiValue {
  const MuiElevations({
    this.none = const [],
    required this.low,
    required this.high,
  });

  factory MuiElevations.of(Brightness brightness) {
    final dark = brightness == .dark;
    return MuiElevations(
      low: [
        BoxShadow(
          color: const Color(0xFF000000).withValues(alpha: dark ? 0.0 : 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
      high: [
        BoxShadow(
          color: const Color(0xFF000000).withValues(alpha: dark ? 0.42 : 0.12),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  final List<BoxShadow> none;
  final List<BoxShadow> low;
  final List<BoxShadow> high;

  @override
  List<Object?> get props => [none, low, high];

  static MuiElevations lerp(MuiElevations a, MuiElevations b, double t) =>
      MuiElevations(
        none: BoxShadow.lerpList(a.none, b.none, t)!,
        low: BoxShadow.lerpList(a.low, b.low, t)!,
        high: BoxShadow.lerpList(a.high, b.high, t)!,
      );
}

@immutable
class MuiStateTokens with MuiValue {
  const MuiStateTokens({
    this.disabledOpacity = 0.38,
    this.disabledContainerOpacity = 0.12,
    this.hoverOpacity = 0.08,
    this.pressedOpacity = 0.12,
    this.focusOpacity = 0.10,
    this.dragOpacity = 0.16,
  });

  final double disabledOpacity;
  final double disabledContainerOpacity;
  final double hoverOpacity;
  final double pressedOpacity;
  final double focusOpacity;
  final double dragOpacity;

  @override
  List<Object?> get props => [
    disabledOpacity,
    disabledContainerOpacity,
    hoverOpacity,
    pressedOpacity,
    focusOpacity,
    dragOpacity,
  ];

  static MuiStateTokens lerp(MuiStateTokens a, MuiStateTokens b, double t) =>
      MuiStateTokens(
        disabledOpacity: lerpDouble(a.disabledOpacity, b.disabledOpacity, t)!,
        disabledContainerOpacity: lerpDouble(
          a.disabledContainerOpacity,
          b.disabledContainerOpacity,
          t,
        )!,
        hoverOpacity: lerpDouble(a.hoverOpacity, b.hoverOpacity, t)!,
        pressedOpacity: lerpDouble(a.pressedOpacity, b.pressedOpacity, t)!,
        focusOpacity: lerpDouble(a.focusOpacity, b.focusOpacity, t)!,
        dragOpacity: lerpDouble(a.dragOpacity, b.dragOpacity, t)!,
      );
}

abstract final class MuiRadius {
  static const BorderRadius sm = BorderRadius.all(Radius.circular(8));
  static const BorderRadius md = BorderRadius.all(Radius.circular(12));
  static const BorderRadius lg = BorderRadius.all(Radius.circular(16));

  static const BorderRadius xl = BorderRadius.all(Radius.circular(24));

  static BorderRadius inside(BorderRadius outer, double inset) {
    Radius shrink(Radius r) =>
        Radius.elliptical(math.max(0, r.x - inset), math.max(0, r.y - inset));
    return BorderRadius.only(
      topLeft: shrink(outer.topLeft),
      topRight: shrink(outer.topRight),
      bottomLeft: shrink(outer.bottomLeft),
      bottomRight: shrink(outer.bottomRight),
    );
  }
}
