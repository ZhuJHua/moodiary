import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_rust/moodiary_rust.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:moodiary_diary/src/presentation/widget/diary_nav.dart';

part 'diary_graph_page.g.dart';

/// 知识图谱数据(只含有双链的日记)。订阅 [DiaryRepository.diaryEvents],任何日记增删改都
/// 令其失效重建;从双链快照直接装配,免解析 content。
@riverpod
Future<DiaryGraphData> diaryGraph(Ref ref) async {
  final repo = DiaryRepository.get();
  final sub = repo.diaryEvents.listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  return repo.buildLinkGraph();
}

class DiaryGraphPage extends ConsumerWidget {
  const DiaryGraphPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(diaryGraphProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.knowledgeGraph)),
      body: async.buildLoading(
        data: (graph) =>
            graph.isEmpty ? const _GraphEmpty() : _GraphView(graph: graph),
      ),
    );
  }
}

class _GraphEmpty extends StatelessWidget {
  const _GraphEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hub_outlined, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              context.l10n.graphEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _TimeFilter { all, last30, thisYear, last365 }

/// 布局风格预设:同一套力模型,只改间距三参(边长/碰撞倍数 + 向心力),稀疏→稠密。
enum _GraphStyle { sparse, normal, dense }

/// 布局与绘制的全部调参,集中一处;耦合值用派生表达式/getter 锁住关系。
/// 唯一的运行时状态是 [style](用户可选,会话级不持久化),间距三参由它驱动;
/// 其余均为 const(力学常量与 d3-force/FA2 惯例同源)。
abstract final class _GraphTuning {
  static _GraphStyle style = _GraphStyle.normal;

  // —— 风格驱动的间距(调参面板实验后固化的三档)——
  static double get springLengthFactor => switch (style) {
        _GraphStyle.sparse => 7.0,
        _GraphStyle.normal => 4.5,
        _GraphStyle.dense => 3.0,
      };
  static double get collideFactor => switch (style) {
        _GraphStyle.sparse => 1.8,
        _GraphStyle.normal => 1.3,
        _GraphStyle.dense => 1.1,
      };
  static double get gravity => switch (style) {
        _GraphStyle.sparse => 0.02,
        _GraphStyle.normal => 0.03,
        _GraphStyle.dense => 0.05,
      };

  // —— 几何(世界单位)。**节点半径是锚**:间距/边长/箭头全由它派生 ——
  static const drawnWorldR = 14.0;
  static const selNodeR = drawnWorldR * 1.5;
  static const edgeWorldWidth = 2.2;
  static const hiEdgeWorldWidth = edgeWorldWidth * 1.6;
  static const arrowLen = drawnWorldR * 0.9; // 箭头与节点同步缩放
  static const arrowHalfW = drawnWorldR * 0.5;

  // —— FA2 力学派生。kr = ka·(SL/2)² → 度数 1 的叶对平衡距恰为 springLength;
  //    度数越高间距自动放大((SL/2)·√(m₁m₂),m=deg+1)——间距随重要度呼吸 ——
  static double get springLength => drawnWorldR * springLengthFactor;
  static double get bigSpringLength => drawnWorldR * (springLengthFactor + 2.5);
  static double get collideRadius => drawnWorldR * collideFactor;
  static double get repulsion =>
      springStrength * (springLength / 2) * (springLength / 2);
  static double get bigRepulsion =>
      springStrength * (bigSpringLength / 2) * (bigSpringLength / 2);

  // —— 力学常量 ——
  static const springStrength = 0.08; // FA2 引力系数 ka
  static const velocityDecay = 0.5; // d3 语义阻尼,越大越黏
  static const theta = 0.9; // Barnes-Hut 开角,小=准而慢
  static const iterations = 300;
  static const frameDelayMs = 10; // 小图沉降 ≈ iterations×frameDelayMs

  // —— 大图阈值 / 淡出 ——
  static const bigNodeCount = 2000; // 布局摊开:斥力/边长改用 big 值
  static const nodesPerEmit = 1200; // emitEvery = N/此值(1..maxEmitEvery)
  static const maxEmitEvery = 12;
  static const denseEdgeCount = 3000; // 边多于此:降透明度防灰雾
  static const arrowMaxEdges = 800; // 多于此不画全量箭头
  static const edgeAlpha = 0.16;
  static const denseEdgeAlpha = 0.07;
  static const fadeFactor = 0.25; // 聚焦时非邻域边 = 边透明度×此值
  static const fadedEdgeFloor = 0.04; // 兜底:密图别淡到等于隐藏
  static const fadedNodeAlpha = 0.16;

  // —— 相机(全景拟合)/ 交互 ——
  static const fitPad = 56.0; // 拟合四周留白
  static const maxInitialFit = 2.0; // 极小图别放过大;手势缩放不受此限
  static const minScale = 0.001; // 除零/NaN 防线
  static const hitRadius = 20.0;
}

class _GraphView extends ConsumerStatefulWidget {
  final DiaryGraphData graph;
  const _GraphView({required this.graph});

  @override
  ConsumerState<_GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends ConsumerState<_GraphView> {
  // —— 筛选 ——
  String? _categoryId; // null = 全部分类
  _TimeFilter _time = _TimeFilter.all;

  // —— 当前(筛选后)子图与布局 ——
  late DiaryGraphData _sub;
  late List<Set<int>> _adj; // 子图邻接表(新下标)
  Float32List _positions = Float32List(0);
  bool _hasLayout = false;
  StreamSubscription<Float32List>? _layoutSub;
  int? _selected;

  // —— 绘制缓冲(世界坐标,GPU 经 canvas 变换绘制;仅布局帧到达时重填,手势零重算)——
  Float32List _edgeBuf = Float32List(0); // [ax,ay,bx,by]×E,与 _sub.edges 同序
  Float32List? _hlNodeBuf; // 选中态:邻居节点坐标
  Float32List? _hlEdgeBuf; // 选中态:关联边端点(a→b 顺序保留,箭头用)
  List<bool> _hlArrowToSel = const []; // 关联边箭头目标是否为选中节点
  final _tick = ValueNotifier<int>(0); // 画布重绘信号(帧/相机),不走 setState
  Size _viewport = Size.zero;

  // 标签 TextPainter 按节点缓存(布局/手势帧间标题与样式不变,重复 layout 是纯浪费);
  // 换图时清空,主题色/文字方向变化时失效。
  final _labelCache = <int, TextPainter>{};
  Color? _labelCacheColor;
  TextDirection? _labelCacheDir;

  // —— 相机(world→screen: p*scale + translate)——
  double _scale = 1;
  Offset _translate = Offset.zero;
  bool _autoFit = true; // 首次交互前自动跟随沉降中的图
  bool _refit = true; // autoFit 时是否重算拟合缩放(keepCamera 重布局则只跟随平移)
  double _startScale = 1;
  Offset _startTranslate = Offset.zero;
  Offset _startFocal = Offset.zero;

  double get _springLength => _sub.nodeCount > _GraphTuning.bigNodeCount
      ? _GraphTuning.bigSpringLength
      : _GraphTuning.springLength;

  GraphLayoutParams _layoutParams(int nodeCount) {
    final big = nodeCount > _GraphTuning.bigNodeCount;
    final emitEvery = (nodeCount / _GraphTuning.nodesPerEmit)
        .clamp(1, _GraphTuning.maxEmitEvery)
        .toInt();
    return GraphLayoutParams(
      iterations: _GraphTuning.iterations,
      theta: _GraphTuning.theta,
      repulsion: big ? _GraphTuning.bigRepulsion : _GraphTuning.repulsion,
      springLength: _springLength,
      springStrength: _GraphTuning.springStrength,
      gravity: _GraphTuning.gravity,
      collideRadius: _GraphTuning.collideRadius,
      velocityDecay: _GraphTuning.velocityDecay,
      emitEvery: emitEvery,
      frameDelayMs: _GraphTuning.frameDelayMs,
    );
  }

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  @override
  void didUpdateWidget(covariant _GraphView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // provider 因 diaryEvents 刷新会传入新图对象 → 重算子图并重跑布局(视角保留)。
    if (!identical(oldWidget.graph, widget.graph)) {
      _rebuild(keepCamera: true);
    }
  }

  @override
  void dispose() {
    _layoutSub?.cancel();
    _tick.dispose();
    super.dispose();
  }

  /// [keepCamera] = 保留当前缩放(数据刷新时视角不被拽走,仅跟随图心平移);
  /// 开页/切筛选/换风格传 false → 重算全景拟合。
  void _rebuild({bool keepCamera = false}) {
    _sub = _subgraph(widget.graph);
    _adj = _buildAdjacency(_sub);
    _selected = null;
    _hlNodeBuf = null;
    _hlEdgeBuf = null;
    _hlArrowToSel = const [];
    _labelCache.clear();
    _refit = !keepCamera;
    _autoFit = true;
    _hasLayout = false;
    _edgeBuf = Float32List(_sub.edgeCount * 4);
    _startLayout();
  }

  void _startLayout() {
    _layoutSub?.cancel();
    if (_sub.nodeCount == 0) {
      _positions = Float32List(0);
      _hasLayout = true;
      return;
    }
    // 布局弹簧按无向处理:互链(A↔B 的两条有向边)去重成一条,避免双倍弹簧。
    final stream = layoutGraphStream(
      nodeCount: _sub.nodeCount,
      edges: _undirectedEdges(_sub.edges),
      initialPositions: Float32List(0),
      params: _layoutParams(_sub.nodeCount),
    );
    _layoutSub = stream.listen((frame) {
      if (!mounted) return;
      _positions = frame;
      _fillEdgeBuf();
      if (_selected != null) _rebuildHlBufs();
      if (_autoFit && !_viewport.isEmpty) _centerCamera(_viewport);
      if (_hasLayout) {
        _tick.value++; // 只重绘画布,不重建 widget 树
      } else {
        setState(() => _hasLayout = true);
      }
    }, onError: (Object _, StackTrace _) {
      // Rust 侧布局错误:降级为已有帧/空画布,别永久卡在 loading。
      if (mounted && !_hasLayout) setState(() => _hasLayout = true);
    });
  }

  void _fillEdgeBuf() {
    final e = _sub.edges;
    final p = _positions;
    if (p.length < _sub.nodeCount * 2) return;
    for (var i = 0, k = 0; i + 1 < e.length; i += 2) {
      final a = e[i] * 2, b = e[i + 1] * 2;
      _edgeBuf[k++] = p[a];
      _edgeBuf[k++] = p[a + 1];
      _edgeBuf[k++] = p[b];
      _edgeBuf[k++] = p[b + 1];
    }
  }

  /// 选中态的高亮小缓冲(邻居点 + 关联边)。只在选中变化/布局帧时重建,规模 = 度数。
  void _rebuildHlBufs() {
    final s = _selected;
    final p = _positions;
    if (s == null || p.length < _sub.nodeCount * 2) {
      _hlNodeBuf = null;
      _hlEdgeBuf = null;
      _hlArrowToSel = const [];
      return;
    }
    final nbrs = _adj[s];
    final nb = Float32List(nbrs.length * 2);
    var k = 0;
    for (final i in nbrs) {
      nb[k++] = p[i * 2];
      nb[k++] = p[i * 2 + 1];
    }
    _hlNodeBuf = nb;
    final e = _sub.edges;
    final segs = <double>[];
    final toSel = <bool>[];
    for (var i = 0; i + 1 < e.length; i += 2) {
      final a = e[i], b = e[i + 1];
      if (a != s && b != s) continue;
      segs
        ..add(p[a * 2])
        ..add(p[a * 2 + 1])
        ..add(p[b * 2])
        ..add(p[b * 2 + 1]);
      toSel.add(b == s);
    }
    _hlEdgeBuf = Float32List.fromList(segs);
    _hlArrowToSel = toSel;
  }

  // —— 子图 = 筛选谓词两端都满足的边 + 其端点(丢弃因筛选而孤立的节点),密集重排 ——
  DiaryGraphData _subgraph(DiaryGraphData full) {
    final range = _timeRange(_time);
    bool keep(DiaryGraphNode n) {
      if (_categoryId != null && n.categoryId != _categoryId) return false;
      if (range != null) {
        final t = n.time.toLocal();
        if (t.isBefore(range.$1) || t.isAfter(range.$2)) return false;
      }
      return true;
    }

    // 无筛选:直接用全图(它本就是 linked-only)。
    if (_categoryId == null && _time == _TimeFilter.all) return full;

    final keptEdges = <(int, int)>[];
    final endpoints = <int>{};
    for (var e = 0; e < full.edgeCount; e++) {
      final a = full.edges[e * 2];
      final b = full.edges[e * 2 + 1];
      if (keep(full.nodes[a]) && keep(full.nodes[b])) {
        keptEdges.add((a, b));
        endpoints
          ..add(a)
          ..add(b);
      }
    }
    if (keptEdges.isEmpty) {
      return DiaryGraphData(nodes: const [], edges: Int32List(0));
    }
    final oldSorted = endpoints.toList()..sort();
    final newIndex = {for (var i = 0; i < oldSorted.length; i++) oldSorted[i]: i};
    final nodes = [
      for (var i = 0; i < oldSorted.length; i++)
        _reindex(full.nodes[oldSorted[i]], i),
    ];
    final edges = Int32List(keptEdges.length * 2);
    for (var i = 0; i < keptEdges.length; i++) {
      final (a, b) = keptEdges[i];
      edges[i * 2] = newIndex[a]!;
      edges[i * 2 + 1] = newIndex[b]!;
    }
    return DiaryGraphData(nodes: nodes, edges: edges);
  }

  static DiaryGraphNode _reindex(DiaryGraphNode n, int i) => DiaryGraphNode(
    index: i,
    id: n.id,
    isarId: n.isarId,
    title: n.title,
    time: n.time,
    categoryId: n.categoryId,
  );

  static List<Set<int>> _buildAdjacency(DiaryGraphData g) {
    final adj = List.generate(g.nodeCount, (_) => <int>{});
    for (var e = 0; e < g.edgeCount; e++) {
      final a = g.edges[e * 2];
      final b = g.edges[e * 2 + 1];
      adj[a].add(b);
      adj[b].add(a);
    }
    return adj;
  }

  // 有向边 → 无向去重(供布局弹簧用):A→B 与 B→A 合成一条,自环丢弃。
  static Int32List _undirectedEdges(Int32List directed) {
    final seen = <String>{};
    final out = <int>[];
    for (var e = 0; e + 1 < directed.length; e += 2) {
      final a = directed[e], b = directed[e + 1];
      if (a == b) continue;
      final lo = a < b ? a : b, hi = a < b ? b : a;
      if (!seen.add('$lo:$hi')) continue;
      out
        ..add(a)
        ..add(b);
    }
    return Int32List.fromList(out);
  }

  (DateTime, DateTime)? _timeRange(_TimeFilter f) {
    final now = DateTime.now();
    return switch (f) {
      _TimeFilter.all => null,
      _TimeFilter.last30 => (now.subtract(const Duration(days: 30)), now),
      _TimeFilter.thisYear => (DateTime(now.year), now),
      _TimeFilter.last365 => (now.subtract(const Duration(days: 365)), now),
    };
  }

  // —— 开局相机:全景拟合,按内容动态算(整图入屏,带留白;极小图上限防过度放大;
  //    下限 minScale 防小视口钳出 0)。keepCamera 重布局时不重算缩放、只跟随图心。
  //    沉降期间每帧跟随,直到用户首次手势。 ——
  void _centerCamera(Size size) {
    if (_positions.length < 2 || size.isEmpty) return;
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (var i = 0; i < _sub.nodeCount; i++) {
      final x = _positions[i * 2], y = _positions[i * 2 + 1];
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }
    if (_refit) {
      const pad = _GraphTuning.fitPad;
      final w = maxX - minX, h = maxY - minY;
      final sx =
          w <= 0 ? _GraphTuning.maxInitialFit : (size.width - pad * 2) / w;
      final sy =
          h <= 0 ? _GraphTuning.maxInitialFit : (size.height - pad * 2) / h;
      _scale = math
          .min(sx, sy)
          .clamp(_GraphTuning.minScale, _GraphTuning.maxInitialFit)
          .toDouble();
    }
    _translate = size.center(Offset.zero) -
        Offset((minX + maxX) / 2, (minY + maxY) / 2) * _scale;
  }

  Offset _screenOf(int i) => Offset(
    _positions[i * 2] * _scale + _translate.dx,
    _positions[i * 2 + 1] * _scale + _translate.dy,
  );

  void _onTapUp(Offset local) {
    const hitRadius = _GraphTuning.hitRadius;
    int? best;
    var bestD = hitRadius;
    for (var i = 0; i < _sub.nodeCount; i++) {
      final d = (_screenOf(i) - local).distance;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    // 选中不动相机(Obsidian 同款):淡出已足够凸显局部,跳视角反而破坏空间感。
    setState(() {
      _selected = best;
      _rebuildHlBufs();
    });
  }

  Future<void> _open(DiaryGraphNode n) async {
    final diary = await DiaryRepository.get().getDiaryByBusinessId(n.id);
    if (diary == null || !mounted) return;
    openDiaryDetail(context, diary);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final categories =
        ref.watch(categoryControllerProvider).value ?? const <Category>[];
    return Column(
      children: [
        _filterBar(context, theme, l10n, categories),
        Expanded(child: _canvas(theme, l10n)),
      ],
    );
  }

  Widget _canvas(ThemeData theme, AppLocalizations l10n) {
    if (_sub.nodeCount == 0 && _hasLayout) {
      return Center(
        child: Text(
          l10n.graphEmpty,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        _viewport = size;
        if (_hasLayout && _autoFit) _centerCamera(size);
        if (!_hasLayout) return const MoodiaryLoading();

        final highlight = _selected == null
            ? null
            : <int>{_selected!, ..._adj[_selected!]};
        final cs = theme.colorScheme;
        final labelDir = Directionality.of(context);
        if (_labelCacheColor != cs.onSurface || _labelCacheDir != labelDir) {
          _labelCache.clear();
          _labelCacheColor = cs.onSurface;
          _labelCacheDir = labelDir;
        }
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: (d) {
                  _autoFit = false;
                  _startScale = _scale;
                  _startTranslate = _translate;
                  _startFocal = d.localFocalPoint;
                },
                onScaleUpdate: (d) {
                  // 上不限倍率;焦点跟随=平移+缩放合一。只改字段 + tick,不 setState:
                  // 手势重绘走 GPU 变换,Dart 侧零重算。下限防双指重合 span=0 → NaN。
                  final ns =
                      math.max(_GraphTuning.minScale, _startScale * d.scale);
                  final world = (_startFocal - _startTranslate) / _startScale;
                  _scale = ns;
                  _translate = d.localFocalPoint - world * ns;
                  _tick.value++;
                },
                onTapUp: (d) => _onTapUp(d.localPosition),
                child: RepaintBoundary(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _tick,
                    builder: (_, tick, _) => CustomPaint(
                      size: Size.infinite,
                      painter: _GraphPainter(
                        tick: tick,
                        positions: _positions,
                        edgeBuf: _edgeBuf,
                        hlNodeBuf: _hlNodeBuf,
                        hlEdgeBuf: _hlEdgeBuf,
                        hlArrowToSel: _hlArrowToSel,
                        edges: _sub.edges,
                        nodes: _sub.nodes,
                        scale: _scale,
                        translate: _translate,
                        selected: _selected,
                        highlight: highlight,
                        nodeColor: cs.primary,
                        edgeColor: cs.onSurface.withValues(
                          alpha: _sub.edgeCount > _GraphTuning.denseEdgeCount
                              ? _GraphTuning.denseEdgeAlpha
                              : _GraphTuning.edgeAlpha,
                        ),
                        edgeHiColor: cs.primary,
                        selColor: cs.tertiary,
                        labelColor: cs.onSurface,
                        labelCache: _labelCache,
                        textDirection: labelDir,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_selected != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: _infoCard(theme, l10n, _sub.nodes[_selected!]),
              ),
          ],
        );
      },
    );
  }

  Widget _filterBar(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    List<Category> categories,
  ) {
    var catName = l10n.graphFilterAllCategories;
    if (_categoryId != null) {
      for (final c in categories) {
        if (c.id == _categoryId) {
          catName = c.categoryName;
          break;
        }
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          MoodiaryMenuButton<String>(
            selected: _categoryId ?? '',
            entries: [
              MoodiaryMenuEntry(value: '', label: l10n.graphFilterAllCategories),
              for (final c in categories)
                MoodiaryMenuEntry(value: c.id, label: c.categoryName),
            ],
            onSelected: (v) {
              setState(() {
                _categoryId = v.isEmpty ? null : v;
                _rebuild();
              });
            },
            child: _chip(theme, Icons.folder_outlined, catName),
          ),
          const SizedBox(width: 8),
          MoodiaryMenuButton<_TimeFilter>(
            selected: _time,
            entries: [
              MoodiaryMenuEntry(value: _TimeFilter.all, label: l10n.graphTimeAll),
              MoodiaryMenuEntry(
                value: _TimeFilter.last30,
                label: l10n.graphTimeLast30,
              ),
              MoodiaryMenuEntry(
                value: _TimeFilter.thisYear,
                label: l10n.graphTimeThisYear,
              ),
              MoodiaryMenuEntry(
                value: _TimeFilter.last365,
                label: l10n.graphTimeLast365,
              ),
            ],
            onSelected: (v) {
              setState(() {
                _time = v;
                _rebuild();
              });
            },
            child: _chip(theme, Icons.schedule_rounded, _timeLabel(l10n, _time)),
          ),
          const SizedBox(width: 8),
          MoodiaryMenuButton<_GraphStyle>(
            tooltip: l10n.graphStyle,
            selected: _GraphTuning.style,
            entries: [
              MoodiaryMenuEntry(
                value: _GraphStyle.sparse,
                label: l10n.graphStyleSparse,
              ),
              MoodiaryMenuEntry(
                value: _GraphStyle.normal,
                label: l10n.graphStyleNormal,
              ),
              MoodiaryMenuEntry(
                value: _GraphStyle.dense,
                label: l10n.graphStyleDense,
              ),
            ],
            onSelected: (v) {
              setState(() {
                _GraphTuning.style = v;
                _rebuild(); // 换风格重布局并重算全景拟合
              });
            },
            child: _chip(
              theme,
              Icons.grain_rounded,
              _styleLabel(l10n, _GraphTuning.style),
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              l10n.graphCount(_sub.nodeCount, _sub.edgeCount),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(ThemeData theme, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelLarge),
          Icon(
            Icons.arrow_drop_down_rounded,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  // 选中节点的信息卡:整卡可点打开(与反向链接 tile 一致)。前导圆点呼应选中节点色,
  // 右侧 chevron 提示可点、× 关闭。
  Widget _infoCard(ThemeData theme, AppLocalizations l10n, DiaryGraphNode n) {
    final cs = theme.colorScheme;
    final title = n.title.trim().isEmpty ? _fmtDate(n.time) : n.title.trim();
    final links = _adj[_selected!].length;
    return Semantics(
      button: true,
      label: l10n.graphOpenDiary,
      child: Material(
        color: cs.surfaceContainerHigh,
        elevation: 2,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(n),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
            child: Row(
              children: [
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: cs.tertiary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_fmtDate(n.time)} · ${l10n.graphNodeLinks(links)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant),
                  onPressed: () => setState(() {
                    _selected = null;
                    _rebuildHlBufs();
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _styleLabel(AppLocalizations l10n, _GraphStyle s) => switch (s) {
    _GraphStyle.sparse => l10n.graphStyleSparse,
    _GraphStyle.normal => l10n.graphStyleNormal,
    _GraphStyle.dense => l10n.graphStyleDense,
  };

  String _timeLabel(AppLocalizations l10n, _TimeFilter f) => switch (f) {
    _TimeFilter.all => l10n.graphTimeAll,
    _TimeFilter.last30 => l10n.graphTimeLast30,
    _TimeFilter.thisYear => l10n.graphTimeThisYear,
    _TimeFilter.last365 => l10n.graphTimeLast365,
  };

  static String _two(int v) => v < 10 ? '0$v' : '$v';
  static String _fmtDate(DateTime t) {
    final l = t.toLocal();
    return '${l.year}-${_two(l.month)}-${_two(l.day)}';
  }
}

class _GraphPainter extends CustomPainter {
  final int tick;
  final Float32List positions; // 世界坐标 [x,y]×N,直接引用布局帧,零拷贝
  final Float32List edgeBuf; // 世界坐标 [ax,ay,bx,by]×E,布局帧到达时填好
  final Float32List? hlNodeBuf; // 选中态:邻居节点(世界坐标)
  final Float32List? hlEdgeBuf; // 选中态:关联边端点(a→b 顺序保留)
  final List<bool> hlArrowToSel;
  final Int32List edges;
  final List<DiaryGraphNode> nodes;
  final double scale;
  final Offset translate;
  final int? selected;
  final Set<int>? highlight;
  final Color nodeColor;
  final Color edgeColor;
  final Color edgeHiColor;
  final Color selColor;
  final Color labelColor;
  final Map<int, TextPainter> labelCache;
  final TextDirection textDirection;

  _GraphPainter({
    required this.tick,
    required this.positions,
    required this.edgeBuf,
    required this.hlNodeBuf,
    required this.hlEdgeBuf,
    required this.hlArrowToSel,
    required this.edges,
    required this.nodes,
    required this.scale,
    required this.translate,
    required this.selected,
    required this.highlight,
    required this.nodeColor,
    required this.edgeColor,
    required this.edgeHiColor,
    required this.selColor,
    required this.labelColor,
    required this.labelCache,
    required this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = nodes.length;
    if (n == 0 || positions.length < n * 2) return;
    final sel = selected;

    // 选中即「聚焦」:非邻域淡出而非隐藏(Obsidian 通行做法),保留全图空间上下文。
    // 下限兜底:大图 edgeColor 本就已是 denseEdgeAlpha,再乘 fadeFactor 会低到不可见。
    final fadedEdge = edgeColor.withValues(
      alpha: math.max(
        _GraphTuning.fadedEdgeFloor,
        _GraphTuning.fadeFactor * edgeColor.a,
      ),
    );
    final fadedNode = nodeColor.withValues(alpha: _GraphTuning.fadedNodeAlpha);

    // —— 纯世界空间直绘:图谱本身恒定,缩放只是相机变换(远缩时边点等比变小自然隐去,
    //    等价于拉远看一张固定的图);缓冲不随手势重建,GPU 承担全部变换。——
    canvas.save();
    canvas.translate(translate.dx, translate.dy);
    canvas.scale(scale);

    if (edgeBuf.isNotEmpty) {
      canvas.drawRawPoints(
        PointMode.lines,
        edgeBuf,
        Paint()
          ..color = sel != null ? fadedEdge : edgeColor
          ..strokeWidth = _GraphTuning.edgeWorldWidth
          ..isAntiAlias = true,
      );
    }
    final hlE = hlEdgeBuf;
    if (sel != null && hlE != null && hlE.isNotEmpty) {
      canvas.drawRawPoints(
        PointMode.lines,
        hlE,
        Paint()
          ..color = edgeHiColor
          ..strokeWidth = _GraphTuning.hiEdgeWorldWidth
          ..isAntiAlias = true,
      );
    }

    canvas.drawRawPoints(
      PointMode.points,
      positions,
      Paint()
        ..color = sel != null ? fadedNode : nodeColor
        ..strokeWidth = _GraphTuning.drawnWorldR * 2
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );
    final hlN = hlNodeBuf;
    if (sel != null && hlN != null && hlN.isNotEmpty) {
      canvas.drawRawPoints(
        PointMode.points,
        hlN,
        Paint()
          ..color = nodeColor
          ..strokeWidth = _GraphTuning.drawnWorldR * 2
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true,
      );
    }
    // 选中大圆与箭头同在世界空间:随图缩放,不是独立的屏幕贴片。
    if (sel != null) {
      canvas.drawCircle(
        Offset(positions[sel * 2], positions[sel * 2 + 1]),
        _GraphTuning.selNodeR,
        Paint()
          ..color = selColor
          ..isAntiAlias = true,
      );
      // 关联边箭头(数量 = 度数)
      final buf = hlEdgeBuf;
      if (buf != null) {
        final headPaint = Paint()
          ..color = edgeHiColor
          ..isAntiAlias = true;
        for (var i = 0, e = 0; i + 3 < buf.length; i += 4, e++) {
          final toSel = e < hlArrowToSel.length && hlArrowToSel[e];
          _arrowHead(
            canvas,
            Offset(buf[i], buf[i + 1]),
            Offset(buf[i + 2], buf[i + 3]),
            headPaint,
            toSel ? _GraphTuning.selNodeR : _GraphTuning.drawnWorldR,
          );
        }
      }
    } else if (edges.length ~/ 2 <= _GraphTuning.arrowMaxEdges) {
      // 小图未选中:全量箭头;远缩时随图等比变小自然隐去,无需特判。
      final headPaint = Paint()
        ..color = edgeColor
        ..isAntiAlias = true;
      for (var i = 0; i + 3 < edgeBuf.length; i += 4) {
        _arrowHead(
          canvas,
          Offset(edgeBuf[i], edgeBuf[i + 1]),
          Offset(edgeBuf[i + 2], edgeBuf[i + 3]),
          headPaint,
          _GraphTuning.drawnWorldR,
        );
      }
    }
    // —— 标签同在世界空间:随图缩放(纯相机模型;字号 11 = scale 1 的原生大小)。
    //    常显(用户定调),仅选中态淡出节点不带标签;视口按世界坐标裁剪。
    //    亚像素省略:字高缩到 <1px 时不可读只剩糊点,跳过纯属省绘制,非显示策略。——
    if (11.0 * scale >= 1.0) {
      final wLeft = -translate.dx / scale, wTop = -translate.dy / scale;
      final wRight = (size.width - translate.dx) / scale;
      final wBottom = (size.height - translate.dy) / scale;
      const wm = 130.0; // 世界边距 ≈ 标签最大宽
      bool inView(double x, double y) =>
          x > wLeft - wm && x < wRight + wm && y > wTop - wm && y < wBottom + wm;
      final hl = highlight;
      if (sel != null && hl != null) {
        for (final i in hl) {
          final x = positions[i * 2], y = positions[i * 2 + 1];
          if (inView(x, y)) _drawLabel(canvas, Offset(x, y), i);
        }
      } else {
        for (var i = 0; i < n; i++) {
          final x = positions[i * 2], y = positions[i * 2 + 1];
          if (inView(x, y)) _drawLabel(canvas, Offset(x, y), i);
        }
      }
    }
    canvas.restore();
  }

  // 在 a→b 方向、贴近 b 节点外缘画实心三角箭头(世界单位,随图同步缩放),标示链接方向。
  void _arrowHead(Canvas canvas, Offset a, Offset b, Paint paint, double dstRadius) {
    final dir = b - a;
    final len = dir.distance;
    if (len < dstRadius + _GraphTuning.arrowLen + 2) return; // 太短放不下箭头
    final u = dir / len;
    final tip = b - u * (dstRadius + 1.5);
    final back = tip - u * _GraphTuning.arrowLen;
    final perp = Offset(-u.dy, u.dx) * _GraphTuning.arrowHalfW;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(back.dx + perp.dx, back.dy + perp.dy)
      ..lineTo(back.dx - perp.dx, back.dy - perp.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawLabel(Canvas canvas, Offset at, int index) {
    final text = nodes[index].title.trim();
    if (text.isEmpty) return;
    // 缓存按节点复用(State 持有,换图/换样式时清空),帧间不再重复 layout。
    final tp = labelCache.putIfAbsent(
      index,
      () => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(color: labelColor, fontSize: 11),
        ),
        textDirection: textDirection,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 120),
    );
    // 世界坐标锚在节点下缘外,随 canvas 变换整体缩放。
    tp.paint(
      canvas,
      Offset(at.dx - tp.width / 2, at.dy + _GraphTuning.drawnWorldR + 4),
    );
  }

  @override
  bool shouldRepaint(covariant _GraphPainter old) =>
      old.tick != tick ||
      !identical(old.positions, positions) ||
      old.scale != scale ||
      old.translate != translate ||
      old.selected != selected ||
      !identical(old.highlight, highlight) ||
      old.nodeColor != nodeColor ||
      old.edgeColor != edgeColor ||
      old.selColor != selColor ||
      old.textDirection != textDirection;
}

