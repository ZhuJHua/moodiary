import 'dart:math' as math;

import 'package:mui/mui.dart';

enum GraphColorMode { category, time, plain }

enum GraphDensity { sparse, normal, dense }

abstract final class GraphTuning {
  static const nodeRadiusMin = 5.0;
  static const nodeRadiusMax = 8.5;
  static const nodeRadiusBase = 14.0;
  static const centerRadius = 9.5;

  static const selectedRingWidth = 1.6;
  static const selectedRingGap = 1.2;
  static const selectedRingMinPx = 1.2;
  static const selectedCoreMinRatio = 0.34;

  static double selectedCoreRadius(double r) => math.max(
    r * selectedCoreMinRatio,
    r - selectedRingWidth - selectedRingGap,
  );

  static const edgeWidth = 0.8;
  static const edgeWidthHi = 1.4;
  static double springLength(GraphDensity d) => switch (d) {
    .sparse => nodeRadiusBase * 7.0,
    .normal => nodeRadiusBase * 4.5,
    .dense => nodeRadiusBase * 3.2,
  };
  static double collideRadius(GraphDensity d) => switch (d) {
    .sparse => 34.0,
    .normal => 27.0,
    .dense => 21.0,
  };
  static double gravity(GraphDensity d) => switch (d) {
    .sparse => 0.02,
    .normal => 0.03,
    .dense => 0.05,
  };

  static const springStrength = 0.08;
  static const velocityDecay = 0.5;
  static const theta = 0.9;
  static const iterations = 600;
  static const bigIterations = 900;
  static const bigNodeCount = 1500;
  static const targetFrames = 110;
  static const frameDelayMs = 16; // 对齐 60Hz
  static const minStepRatio = 0.001;
  static const refreshAlpha = 0.3;

  static double repulsion(GraphDensity d) {
    final sl = springLength(d);
    return springStrength * (sl / 2) * (sl / 2);
  }

  static const dotSpacing = 48.0;
  static const dotSpacingSparse = 192.0;
  static const dotMinPx = 14.0;
  static const dotMaxPx = 160.0;

  static const labelSize = 11.0;
  static const labelMaxWidth = 116.0;
  static const labelMaxChars = 10;
  static const labelMaxCharsBody = 5;
  static const labelMaxCount = 140;
  static const labelCellPx = 30.0;

  static const fitPad = 64.0;

  static const maxInitialFit = 1.0;
  static const minScale = 0.02;
  static const maxScale = 24.0;
  static const hitPadPx = 12.0;
  static const flingFriction = 0.92;
  static const flingStopPx = 40.0;

  static const settleDuration = Duration(milliseconds: 260);
  static const focusDuration = Duration(milliseconds: 220);
  static const unfocusDuration = Duration(milliseconds: 180);
  static const cameraDuration = Duration(milliseconds: 420);

  static double radiusOf(int degree, int cap) {
    if (cap <= 1) return nodeRadiusMin;
    final t = ((degree.clamp(1, cap) - 1) / (cap - 1)).clamp(0.0, 1.0);
    return nodeRadiusMin + (nodeRadiusMax - nodeRadiusMin) * math.sqrt(t);
  }
}

class GraphPalette {
  final bool isDark;
  final Color surface;
  final Color dot;
  final Color spotlight;
  final Color vignette;
  final Color edge;
  final Color label;
  final Color labelHalo;
  final Color fallbackNode;
  final Color outgoing;
  final Color incoming;

  const GraphPalette._({
    required this.isDark,
    required this.surface,
    required this.dot,
    required this.spotlight,
    required this.vignette,
    required this.edge,
    required this.label,
    required this.labelHalo,
    required this.fallbackNode,
    required this.outgoing,
    required this.incoming,
  });

  factory GraphPalette.of(ColorScheme cs, {required int edgeCount}) {
    final dark = cs.brightness == .dark;
    final dense = edgeCount > 3000;
    final edgeAlpha = dense ? (dark ? 0.08 : 0.09) : (dark ? 0.16 : 0.18);
    return GraphPalette._(
      isDark: dark,
      surface: cs.surface,
      dot: cs.onSurface.withValues(alpha: dark ? 0.055 : 0.045),
      spotlight: cs.primary.withValues(alpha: dark ? 0.07 : 0.045),
      vignette: dark ? cs.scrim.withValues(alpha: 0.30) : Colors.transparent,
      edge: cs.onSurface.withValues(alpha: edgeAlpha),
      label: cs.onSurface.withValues(alpha: dark ? 0.90 : 0.88),
      labelHalo: cs.surface,
      fallbackNode: cs.primary,
      outgoing: cs.primary,
      incoming: cs.tertiary,
    );
  }

  Color dim(Color c) => c.withValues(alpha: isDark ? 0.22 : 0.20);

  Color dimEdge(Color c) => c.withValues(alpha: math.max(0.045, c.a * 0.25));

  // 值相等：靠它判断主题是否真的变了，去掉会导致每帧重建场景（重启动画）。
  @override
  bool operator ==(Object other) =>
      other is GraphPalette &&
      other.isDark == isDark &&
      other.surface == surface &&
      other.dot == dot &&
      other.spotlight == spotlight &&
      other.vignette == vignette &&
      other.edge == edge &&
      other.label == label &&
      other.labelHalo == labelHalo &&
      other.fallbackNode == fallbackNode &&
      other.outgoing == outgoing &&
      other.incoming == incoming;

  @override
  int get hashCode => Object.hash(
    isDark,
    surface,
    dot,
    spotlight,
    vignette,
    edge,
    label,
    labelHalo,
    fallbackNode,
    outgoing,
    incoming,
  );
}
