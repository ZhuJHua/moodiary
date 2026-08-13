import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 节点着色维度（总图可切，ego 图固定按分类）。
enum GraphColorMode { category, time, plain }

/// 布局疏密预设：同一套力模型，只改边长 / 碰撞半径 / 向心力三参。
enum GraphDensity { sparse, normal, dense }

/// 图谱的全部视觉与力学调参，集中一处。
///
/// **尺度前提**：Rust 布局开了 `normalizeScale`，发回的坐标里「相连节点距离的中位数」
/// 恒等于 [springLength]。所以下面这些世界单位是稳定的——不论 3 个节点还是 2000 个，
/// 节点半径与边长的比例都一样（这正是旧版远看只剩针尖的根因）。
abstract final class GraphTuning {
  // —— 节点几何（世界单位）——
  // 半径明显小于布局锚（nodeRadiusBase 只管边长），图面留白更多、不显臃肿。
  // 区间收窄的理由：ego 图里邻居大多只有一条链，度数全是 1，会集体压在最小半径上，
  // 中心再取 10 就成了「一个大球 + 一圈针尖」。现在中心只有叶子的 1.9 倍（面积 3.6 倍）。
  static const nodeRadiusMin = 5.0;
  static const nodeRadiusMax = 8.5;
  static const nodeRadiusBase = 14.0; // 布局边长的锚（不直接用于绘制）
  static const centerRadius = 9.5; // ego 中心节点，不参与度数映射

  // —— 选中态：断环 ——
  //
  // **外径恒等于节点本身的半径**：选中不是「长大一圈」，而是同一个圆盘从实心变成
  // 「小实心 + 留白 + 外环」。占位不变带来两个好处：边的内缩量与未选中时一模一样
  // （环永远压不到线，也不必随聚焦进度重算边网格），画面不会因为选中而局部胀大。
  static const selectedRingWidth = 1.6; // 环宽（世界单位）
  static const selectedRingGap = 1.2; // 环内缘到实心圆之间的留白
  static const selectedRingMinPx = 1.2; // 环的屏幕最小宽度；不够粗时只向内长
  static const selectedCoreMinRatio = 0.34; // 实心圆最小占比，小节点不至于缩没

  /// 选中态里那颗实心圆的半径（外径仍是 [r]，缩的是芯）。
  static double selectedCoreRadius(double r) => math.max(
    r * selectedCoreMinRatio,
    r - selectedRingWidth - selectedRingGap,
  );

  // —— 边（含常态箭头，与边同色同网格）——
  static const edgeWidth = 0.8;
  static const edgeWidthHi = 1.4;
  // —— 力学（疏密三档）——
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

  static const springStrength = 0.08; // FA2 引力系数 ka
  static const velocityDecay = 0.5;
  static const theta = 0.9;
  static const iterations = 600; // 配合 emitEvery 降频：同样墙钟跑更多步，交叉少 ~30%
  static const bigIterations = 900;
  static const bigNodeCount = 1500;
  static const targetFrames = 110; // 动画帧数恒定，与图规模无关
  static const frameDelayMs = 16; // 对齐 60Hz；10ms 等于请求 100fps，纯浪费
  static const minStepRatio = 0.001; // 收敛提前退出阈值（× springLength）
  static const refreshAlpha = 0.3; // 增量重布局的起始 alpha，避免整图炸开

  /// kr = ka·(SL/2)² —— 度数 1 的叶对平衡距即 springLength。
  static double repulsion(GraphDensity d) {
    final sl = springLength(d);
    return springStrength * (sl / 2) * (sl / 2);
  }

  // —— 背景 ——
  static const dotSpacing = 48.0;
  static const dotSpacingSparse = 192.0;
  static const dotMinPx = 14.0; // 屏幕间距小于此不画点阵（否则糊成灰雾）
  static const dotMaxPx = 160.0;

  // —— 标签（屏幕空间固定字号：任何缩放都清晰，glyph atlas 零重栅格）——
  static const labelSize = 11.0;
  static const labelMaxWidth = 116.0;
  static const labelMaxChars = 10; // 有标题：标题的字数上限
  static const labelMaxCharsBody = 5; // 无标题：取正文开头，正文比标题嘈杂，短一点
  static const labelMaxCount = 140; // 单帧上限
  static const labelCellPx = 30.0; // 贪心占位网格

  // —— 相机 / 交互 ——
  static const fitPad = 64.0;

  /// 初始拟合的放大上限 —— **不放大**。
  ///
  /// 世界单位已经被 `normalizeScale` 标定过（相连节点距离的中位数恒等于 [springLength]），
  /// 所以 1x 就是这套半径 / 边长设计出来的密度。之前上限是 2.2：节点少的局部图包围盒小，
  /// 拟合算出的倍率顶到天花板，整张图被放大 2.2 倍铺满屏幕，节点看着就是一颗颗大球。
  /// 图比屏幕大时照常缩小，只是不再往上撑。
  static const maxInitialFit = 1.0;
  static const minScale = 0.02;
  static const maxScale = 24.0;
  static const hitPadPx = 12.0;
  static const flingFriction = 0.92;
  static const flingStopPx = 40.0;

  // —— 动效 ——
  static const settleDuration = Duration(milliseconds: 260);
  static const focusDuration = Duration(milliseconds: 220);
  static const unfocusDuration = Duration(milliseconds: 180);
  static const cameraDuration = Duration(milliseconds: 420);

  /// 度数 → 绘制半径。sqrt 映射使面积正比于度数；[cap] 取当前子图度数的 95 分位，
  /// 保证小图也有区分度、大图不被单个 hub 拉平。
  static double radiusOf(int degree, int cap) {
    if (cap <= 1) return nodeRadiusMin;
    final t = ((degree.clamp(1, cap) - 1) / (cap - 1)).clamp(0.0, 1.0);
    return nodeRadiusMin + (nodeRadiusMax - nodeRadiusMin) * math.sqrt(t);
  }
}

/// 一套解析好的图谱配色（跟随 M3 动态取色 + 明暗）。
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
      // scrim 是遮罩基色（不含 alpha），vignette 正是这个用途。
      vignette: dark ? cs.scrim.withValues(alpha: 0.30) : Colors.transparent,
      edge: cs.onSurface.withValues(alpha: edgeAlpha),
      label: cs.onSurface.withValues(alpha: dark ? 0.90 : 0.88),
      labelHalo: cs.surface,
      // 无分类的节点走主题色；出/入链的边色与页面顶部的方向图例同源，不再另调一套。
      fallbackNode: cs.primary,
      outgoing: cs.primary,
      incoming: cs.tertiary,
    );
  }

  /// 聚焦态下非邻域节点的淡出色。
  Color dim(Color c) => c.withValues(alpha: isDark ? 0.22 : 0.20);

  /// 聚焦态下非邻域边的淡出色（密图已经很淡，乘完要托底）。
  Color dimEdge(Color c) => c.withValues(alpha: math.max(0.045, c.a * 0.25));

  // 值相等：调用方每帧都会 `GraphPalette.of(colors)` 出一个新实例，靠它判断「主题真的变了吗」，
  // 没有这个就会每帧重建场景（进而重启动画）。
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
