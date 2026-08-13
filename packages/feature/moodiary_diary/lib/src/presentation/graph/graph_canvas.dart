import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui show Vertices;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:moodiary_diary/src/presentation/graph/graph_scene.dart';
import 'package:moodiary_diary/src/presentation/graph/graph_style.dart';
import 'package:mui/mui.dart';

/// 布局产出的坐标帧。布局侧（Rust 流 / ego 径向）只管往里写，画布订阅重绘。
class GraphFrame extends ChangeNotifier {
  Float32List _positions = Float32List(0);
  bool _settled = false;

  Float32List get positions => _positions;
  bool get settled => _settled;

  void push(Float32List p, {bool settled = false}) {
    _positions = p;
    _settled = settled;
    notifyListeners();
  }

  void markSettled() {
    if (_settled) return;
    _settled = true;
    notifyListeners();
  }
}

/// 画布把手：页面上的浮动按钮用它请求「回到全景 / 回到中心」，并观察相机是否被挪过
/// （用于按钮的淡入淡出）。
class GraphCanvasController extends ChangeNotifier {
  VoidCallback? _onFit;
  bool _userMoved = false;

  bool get userMoved => _userMoved;

  void fit() => _onFit?.call();

  void _setMoved(bool v) {
    if (_userMoved == v) return;
    _userMoved = v;
    notifyListeners();
  }
}

/// 图谱画布：相机 / 手势 / 命中测试 / 绘制。总图与 ego 图共用，差异只在
/// 「坐标从哪来」与 [egoDirections]（方位方向着色）。
class GraphCanvas extends StatefulWidget {
  final GraphScene scene;
  final GraphFrame frame;
  final GraphPalette palette;
  final int? selected;
  final ValueChanged<int?> onSelect;
  final bool showLabels;
  final GraphCanvasController? controller;

  /// ego 图：每个一跳节点相对中心的方向，用于边着色；null = 总图。
  final List<EgoDirection?>? egoDirections;

  /// 给定则按「固定视觉密度」拟合（ego 图，中心恒在屏幕中央），否则按包围盒全景。
  final double? preferredExtent;

  const GraphCanvas({
    super.key,
    required this.scene,
    required this.frame,
    required this.palette,
    required this.selected,
    required this.onSelect,
    this.showLabels = true,
    this.controller,
    this.egoDirections,
    this.preferredExtent,
  });

  @override
  State<GraphCanvas> createState() => _GraphCanvasState();
}

class _GraphCanvasState extends State<GraphCanvas>
    with TickerProviderStateMixin {
  // —— 相机（world→screen: p*scale + translate）——
  double _scale = 1;
  Offset _translate = .zero;
  bool _autoFit = true;
  Size _viewport = .zero;

  double _startScale = 1;
  Offset _startTranslate = .zero;
  Offset _startFocal = .zero;

  // —— 绘制缓冲（世界坐标；手势只改相机，缓冲不重建）——
  Float32List _nodeBuf = Float32List(0);
  ui.Vertices? _edgeMesh;

  // —— 动画 ——
  late final AnimationController _focusCtl;
  late final AnimationController _exitCtl;
  late final AnimationController _settleCtl;
  late final AnimationController _cameraCtl;
  Ticker? _fling;
  Offset _flingVelocity = .zero;
  double _camFromScale = 1, _camToScale = 1;
  Offset _camFromT = .zero, _camToT = .zero;

  /// 聚焦中的节点。取消选中时保留到淡出动画走完，否则「取消」是一瞬间的跳变。
  int? _focusIndex;

  /// 换选中时正在淡出的**上一个**焦点。新旧两头同时动（旧的收、新的长），
  /// 否则 A→B 时 `_focusCtl` 已经在 1，forward() 直接完成、一个 tick 都不发 —— 就是跳变。
  int? _exitIndex;

  final _repaint = ValueNotifier<int>(0);

  // 复用的 Paint / 渐变 shader：绘制命令在录制时就拷走了参数，复用安全且省掉每帧几十次分配。
  final _paint = Paint()..isAntiAlias = true;
  Shader? _spotShader;
  Shader? _vignetteShader;
  Size _shaderSize = .zero;

  // 标签 TextPainter 缓存（帧间标题不变，重复 layout 是纯浪费）。
  final _labels = <int, TextPainter>{};
  Color? _labelColor;
  TextDirection? _labelDir;
  double _labelFactor = 1;
  TextStyle? _labelTemplate;

  double get _focusT => _focusCtl.value;
  double get _exitT => _exitIndex == null ? 0.0 : _exitCtl.value;
  double get _settleT => _settleCtl.value;

  @override
  void initState() {
    super.initState();
    _focusIndex = widget.selected;
    _focusCtl = AnimationController(
      vsync: this,
      duration: GraphTuning.focusDuration,
      reverseDuration: GraphTuning.unfocusDuration,
    )..addListener(_bump);
    _focusCtl.addStatusListener(_onFocusStatus);
    _exitCtl = AnimationController(
      vsync: this,
      duration: GraphTuning.unfocusDuration,
    )..addListener(_bump);
    _exitCtl.addStatusListener(_onExitStatus);
    _settleCtl = AnimationController(
      vsync: this,
      duration: GraphTuning.settleDuration,
    )..addListener(_onSettleTick);
    _cameraCtl = AnimationController(
      vsync: this,
      duration: GraphTuning.cameraDuration,
    )..addListener(_onCameraTick);
    widget.frame.addListener(_onFrame);
    widget.controller?._onFit = _animateFit;
    if (widget.selected != null) _focusCtl.value = 1;
    if (widget.frame.settled) _settleCtl.value = 1;
    _onFrame();
  }

  @override
  void didUpdateWidget(covariant GraphCanvas old) {
    super.didUpdateWidget(old);
    if (!identical(old.frame, widget.frame)) {
      old.frame.removeListener(_onFrame);
      widget.frame.addListener(_onFrame);
      _settleCtl.value = widget.frame.settled ? 1 : 0;
    }
    if (old.controller != widget.controller) {
      old.controller?._onFit = null;
      widget.controller?._onFit = _animateFit;
    }
    final sceneChanged = !identical(old.scene, widget.scene);
    if (sceneChanged) {
      _clearLabels();
      // 只换配色 / 标签开关时节点数不变，别把用户的视角拽回全景。
      if (old.scene.nodeCount != widget.scene.nodeCount) {
        _autoFit = true;
        widget.controller?._setMoved(false);
        _stopFling();
        _cameraCtl.stop();
      }
      if (!widget.frame.settled) _settleCtl.value = 0;
      // 场景缩小（换筛选 / 换深度）后，正在淡出的旧焦点下标可能已越界：立即作废，
      // 否则 _paintFocus 会用陈旧下标越界访问。
      if (_focusIndex != null && _focusIndex! >= widget.scene.nodeCount) {
        _focusIndex = null;
        _focusCtl.value = 0;
      }
      if (_exitIndex != null && _exitIndex! >= widget.scene.nodeCount) {
        _exitIndex = null;
        _exitCtl.value = 0;
      }
    }
    if (old.selected != widget.selected) {
      if (widget.selected != null) {
        // 换选中（A→B）：旧焦点交给 _exitCtl 接着收，新焦点从 0 长出来，两头同时动。
        // 少了这一步，_focusCtl 已经停在 1，forward() 直接完成，B 是「啪」地出现的。
        if (_focusIndex != null &&
            _focusIndex != widget.selected &&
            _focusCtl.value > 0) {
          _exitIndex = _focusIndex;
          _exitCtl.value = _focusCtl.value;
          _exitCtl.reverse();
        }
        _focusIndex = widget.selected;
        _focusCtl.forward(from: 0);
      } else {
        _focusCtl.reverse();
      }
    }
    if (sceneChanged ||
        old.selected != widget.selected ||
        old.palette != widget.palette ||
        old.showLabels != widget.showLabels ||
        !identical(old.egoDirections, widget.egoDirections)) {
      _rebuildBuffers();
      // shouldRepaint 恒为 false，重绘全靠 _repaint：换配色 / 标签 / 主题这类不推坐标帧、
      // 不启动动画的变更，必须在这里主动 bump，否则画布停在旧帧。
      _bump();
    }
  }

  @override
  void dispose() {
    widget.frame.removeListener(_onFrame);
    widget.controller?._onFit = null;
    _stopFling();
    _focusCtl.dispose();
    _exitCtl.dispose();
    _settleCtl.dispose();
    _cameraCtl.dispose();
    _edgeMesh?.dispose();
    _clearLabels();
    _repaint.dispose();
    super.dispose();
  }

  void _bump() => _repaint.value++;

  void _clearLabels() {
    for (final tp in _labels.values) {
      tp.dispose();
    }
    _labels.clear();
  }

  void _onFocusStatus(AnimationStatus status) {
    if (status == .dismissed && widget.selected == null) {
      _focusIndex = null;
      _rebuildBuffers();
      _bump();
    }
  }

  void _onExitStatus(AnimationStatus status) {
    if (status == .dismissed && _exitIndex != null) {
      _exitIndex = null;
      _bump();
    }
  }

  // 落定动画只用来淡入节点的底色描边（边是直线，与 settle 无关）。
  void _onSettleTick() => _bump();

  void _onFrame() {
    if (widget.frame.settled) {
      if (_settleT < 1) _settleCtl.forward();
    } else if (_settleCtl.value != 0) {
      // 新一轮布局开跑：边先绷直，落定时再放松成弧。
      _settleCtl
        ..stop()
        ..value = 0;
    }
    _rebuildBuffers();
    if (_autoFit && !_viewport.isEmpty) _fitCamera(_viewport);
    _bump();
  }

  // —— 缓冲填充：只在布局帧 / 选中 / 主题变化时跑，手势期零重算 ——

  void _rebuildBuffers() {
    final scene = widget.scene;
    final pos = widget.frame.positions;
    final n = scene.nodeCount;
    if (pos.length != n * 2) return;
    if (_nodeBuf.length != n * 2) _nodeBuf = Float32List(n * 2);
    final order = scene.drawOrder;
    for (var k = 0; k < n; k++) {
      final i = order[k];
      _nodeBuf[k * 2] = pos[i * 2];
      _nodeBuf[k * 2 + 1] = pos[i * 2 + 1];
    }
    _rebuildEdgeMesh();
  }

  Color _edgeBaseColor(int a, int b) {
    final palette = widget.palette;
    final center = widget.scene.centerIndex;
    if (widget.egoDirections != null && center != null) {
      // ego：边独占方向编码（出链 primary / 入链 tertiary），节点仍是分类色，两个通道不打架。
      if (a == center) return palette.outgoing.withValues(alpha: 0.8);
      if (b == center) return palette.incoming.withValues(alpha: 0.8);
    }
    return palette.edge;
  }

  /// 边：**直线** + 常态箭头，同一网格一次画完（每条边 = 线身四边形 6 顶点 + 箭头 3 顶点，
  /// 不用 indices 以规避 Uint16 上限）。用 drawVertices 是为了逐边配色（ego 出链 primary /
  /// 入链 tertiary）；箭头与边同色但透明度抬高——线淡箭头实，方向常读。
  void _rebuildEdgeMesh() {
    final scene = widget.scene;
    final pos = widget.frame.positions;
    final ec = scene.edgeCount;
    if (ec == 0 || pos.length != scene.nodeCount * 2) {
      _edgeMesh?.dispose();
      _edgeMesh = null;
      return;
    }
    // 选中态外径恒等于节点半径，端点内缩量因此**与选中无关** —— 边不参与聚焦动画，
    // 这份网格只在换选中 / 换坐标帧 / 换主题时重建一次，手势期与动画期都零重算。
    final rawSel = _focusIndex;
    final sel = (rawSel != null && rawSel < scene.nodeCount) ? rawSel : null;
    final palette = widget.palette;
    final xy = Float32List(ec * 9 * 2);
    final colors = Int32List(ec * 9);
    final edges = scene.edges;
    final radii = scene.radii;

    var v = 0;
    for (var k = 0; k < ec; k++) {
      final a = edges[k * 2], b = edges[k * 2 + 1];
      var base = _edgeBaseColor(a, b);
      var width = widget.egoDirections != null ? 0.9 : GraphTuning.edgeWidth;
      if (sel != null) {
        if (a == sel || b == sel) {
          base = scene.colors[a]; // 关联边取「源节点」色：一眼看出这条链来自哪一类
          width = GraphTuning.edgeWidthHi;
        } else {
          base = palette.dimEdge(base);
        }
      }

      final rawAx = pos[a * 2], rawAy = pos[a * 2 + 1];
      final rawBx = pos[b * 2], rawBy = pos[b * 2 + 1];
      final dx = rawBx - rawAx, dy = rawBy - rawAy;
      final len = math.sqrt(dx * dx + dy * dy);
      // 箭头跟目标节点半径走，小而克制。
      final headLen = 2.4 + radii[b] * 0.24;
      final halfW = headLen * 0.38;
      final trimA = radii[a] + 1.0, trimB = radii[b] + 1.5;
      if (!len.isFinite || len <= trimA + trimB + headLen + 2) {
        v += 9; // 退化：留零 → 零面积三角形，不出像素
        continue;
      }
      // 端点内缩到节点外缘，边不插进圆里。
      final ux = dx / len, uy = dy / len;
      final ax = rawAx + ux * trimA, ay = rawAy + uy * trimA;
      final tipX = rawBx - ux * trimB, tipY = rawBy - uy * trimB;
      // 线身止于箭头底，半透明下叠加会出深斑。
      final backX = tipX - ux * headLen, backY = tipY - uy * headLen;

      final hw = width / 2;
      final nx = -uy * hw, ny = ux * hw;
      final c = base.toARGB32();
      _quad(
        xy,
        colors,
        v,
        ax + nx,
        ay + ny,
        ax - nx,
        ay - ny,
        backX - nx,
        backY - ny,
        backX + nx,
        backY + ny,
        c,
        c,
      );
      v += 6;

      final ac = base
          .withValues(alpha: (base.a * 2.2).clamp(0.0, 0.95))
          .toARGB32();
      final px = -uy * halfW, py = ux * halfW;
      xy[v * 2] = tipX;
      xy[v * 2 + 1] = tipY;
      colors[v] = ac;
      xy[(v + 1) * 2] = backX + px;
      xy[(v + 1) * 2 + 1] = backY + py;
      colors[v + 1] = ac;
      xy[(v + 2) * 2] = backX - px;
      xy[(v + 2) * 2 + 1] = backY - py;
      colors[v + 2] = ac;
      v += 3;
    }
    _edgeMesh?.dispose();
    _edgeMesh = .raw(.triangles, xy, colors: colors);
  }

  /// 写入一个四边形（两个三角形；不用 indices 以规避 Uint16 顶点上限）。
  static void _quad(
    Float32List xy,
    Int32List colors,
    int v,
    double x0,
    double y0,
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
    int cStart,
    int cEnd,
  ) {
    void put(int i, double x, double y, int c) {
      xy[(v + i) * 2] = x;
      xy[(v + i) * 2 + 1] = y;
      colors[v + i] = c;
    }

    put(0, x0, y0, cStart);
    put(1, x1, y1, cStart);
    put(2, x2, y2, cEnd);
    put(3, x0, y0, cStart);
    put(4, x2, y2, cEnd);
    put(5, x3, y3, cEnd);
  }

  // —— 相机 ——

  void _fitCamera(Size size) {
    final pos = widget.frame.positions;
    final n = widget.scene.nodeCount;
    if (pos.length != n * 2 || n == 0 || size.isEmpty) return;
    final extent = widget.preferredExtent;
    if (extent != null && extent > 0) {
      // ego：固定视觉密度 —— 只有两个邻居时也是大而舒展，而不是三个小点飘在正中。
      _scale = (math.min(size.width, size.height) * 0.42 / extent).clamp(
        0.35,
        1.6,
      );
      _translate = size.center(.zero);
      return;
    }
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (var i = 0; i < n; i++) {
      final x = pos[i * 2], y = pos[i * 2 + 1];
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    if (!minX.isFinite || !minY.isFinite) return;
    const pad = GraphTuning.fitPad;
    final w = maxX - minX, h = maxY - minY;
    final sx = w <= 0 ? GraphTuning.maxInitialFit : (size.width - pad * 2) / w;
    final sy = h <= 0 ? GraphTuning.maxInitialFit : (size.height - pad * 2) / h;
    _scale = math
        .min(sx, sy)
        .clamp(GraphTuning.minScale, GraphTuning.maxInitialFit)
        .toDouble();
    _translate =
        size.center(.zero) -
        Offset((minX + maxX) / 2, (minY + maxY) / 2) * _scale;
  }

  void _animateFit() {
    if (_viewport.isEmpty) return;
    _stopFling();
    final s0 = _scale, t0 = _translate;
    _fitCamera(_viewport);
    _camFromScale = s0;
    _camToScale = _scale;
    _camFromT = t0;
    _camToT = _translate;
    _scale = s0;
    _translate = t0;
    _autoFit = true;
    widget.controller?._setMoved(false);
    _cameraCtl.forward(from: 0);
  }

  void _onCameraTick() {
    final t = Curves.easeInOutCubic.transform(_cameraCtl.value);
    // scale 走对数插值：线性插值缩放会有「先慢后爆冲」的错觉。
    _scale = math.exp(lerpD(math.log(_camFromScale), math.log(_camToScale), t));
    _translate = Offset.lerp(_camFromT, _camToT, t)!;
    _bump();
  }

  void _stopFling() {
    _fling?.dispose();
    _fling = null;
    _flingVelocity = .zero;
  }

  void _startFling(Offset velocity) {
    if (velocity.distance < GraphTuning.flingStopPx * 3) return;
    _flingVelocity = velocity;
    _fling?.dispose();
    var last = Duration.zero;
    _fling = createTicker((elapsed) {
      final dt = (elapsed - last).inMicroseconds / 1e6;
      last = elapsed;
      if (dt <= 0) return;
      _translate += _flingVelocity * dt;
      _flingVelocity *= math.pow(GraphTuning.flingFriction, dt * 60).toDouble();
      if (_flingVelocity.distance < GraphTuning.flingStopPx) _stopFling();
      _bump();
    })..start();
  }

  // —— 命中测试：半径感知（画多大就能点多大），平方距离比较、零 Offset 分配 ——
  int? _hitTest(Offset local) {
    final scene = widget.scene;
    final pos = widget.frame.positions;
    if (pos.length != scene.nodeCount * 2) return null;
    var best = -1;
    var bestD2 = double.infinity;
    for (var i = 0; i < scene.nodeCount; i++) {
      final dx = pos[i * 2] * _scale + _translate.dx - local.dx;
      final dy = pos[i * 2 + 1] * _scale + _translate.dy - local.dy;
      final d2 = dx * dx + dy * dy;
      final r = scene.radii[i] * _scale + GraphTuning.hitPadPx;
      if (d2 <= r * r && d2 < bestD2) {
        bestD2 = d2;
        best = i;
      }
    }
    return best < 0 ? null : best;
  }

  TextPainter _labelPainter(int i) {
    return _labels.putIfAbsent(i, () {
      final text = graphNodeLabel(widget.scene.nodes[i]);
      final halo = widget.palette.labelHalo;
      return TextPainter(
        text: TextSpan(
          text: text,
          style: _labelTemplate!.copyWith(
            // 标题、正文摘要、日期一视同仁：来源不同不该体现成深浅不一。
            color: widget.palette.label,
            // 一律同一档：选中不改字号字重，免得标签跟着「跳一下」。
            fontSize: GraphTuning.labelSize * _labelFactor,
            height: 1.1,
            // 底色描边两遍：标签压在边和点阵上仍然可读。
            shadows: [
              Shadow(color: halo, blurRadius: widget.palette.isDark ? 4 : 3),
              Shadow(color: halo, blurRadius: widget.palette.isDark ? 4 : 3),
            ],
          ),
        ),
        textDirection: _labelDir ?? .ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: GraphTuning.labelMaxWidth * _labelFactor);
    });
  }

  void _ensureShaders(Size size) {
    if (_shaderSize == size && _spotShader != null) return;
    _shaderSize = size;
    final rect = Offset.zero & size;
    _spotShader = RadialGradient(
      center: const Alignment(0, -0.15),
      radius: 0.95,
      colors: [widget.palette.spotlight, Colors.transparent],
    ).createShader(rect);
    _vignetteShader = widget.palette.vignette.a > 0
        ? RadialGradient(
            radius: 0.78,
            colors: [Colors.transparent, widget.palette.vignette],
          ).createShader(rect)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final dir = Directionality.of(context);
    // 画布自己 layout 文本，吃不到 MediaQuery 的自动缩放，所以把系统字号倍率
    // 显式取出来乘进标签几何（节点间距也按它放大，否则大字号下标签会糊成一片）。
    final template = context.theme.typography.labelSmall.onSurface;
    final factor = MediaQuery.textScalerOf(context).scale(11) / 11;
    if (_labelColor != widget.palette.label ||
        _labelDir != dir ||
        _labelFactor != factor ||
        _labelTemplate != template) {
      _clearLabels();
      _labelColor = widget.palette.label;
      _labelDir = dir;
      _labelFactor = factor;
      _labelTemplate = template;
      _shaderSize = .zero; // 主题变了，渐变也要重建
      // 标签 / 渐变缓存刚被清空，但重绘只认 _repaint —— 帧后补一次，避免停在旧样式。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _bump();
      });
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (_viewport != size) {
          _viewport = size;
          _shaderSize = .zero;
          if (_autoFit) _fitCamera(size);
        }
        return GestureDetector(
          behavior: .opaque,
          onScaleStart: (d) {
            _stopFling();
            _cameraCtl.stop();
            _autoFit = false;
            widget.controller?._setMoved(true);
            _startScale = _scale;
            _startTranslate = _translate;
            _startFocal = d.localFocalPoint;
          },
          onScaleUpdate: (d) {
            // 焦点跟随 = 平移 + 缩放合一；只改字段 + 重绘信号，不 setState，
            // 手势期间 Dart 侧零重算（缓冲是世界坐标，变换交给 GPU）。
            final ns = (_startScale * d.scale).clamp(
              GraphTuning.minScale,
              GraphTuning.maxScale,
            );
            final world = (_startFocal - _startTranslate) / _startScale;
            _scale = ns;
            _translate = d.localFocalPoint - world * ns;
            _bump();
          },
          onScaleEnd: (d) => _startFling(d.velocity.pixelsPerSecond),
          onTapUp: (d) {
            final hit = _hitTest(d.localPosition);
            if (hit != widget.selected) HapticFeedback.selectionClick();
            widget.onSelect(hit);
          },
          child: RepaintBoundary(
            child: CustomPaint(size: .infinite, painter: _GraphPainter(this)),
          ),
        );
      },
    );
  }
}

double lerpD(double a, double b, double t) => a + (b - a) * t;

class _GraphPainter extends CustomPainter {
  final _GraphCanvasState s;

  _GraphPainter(this.s) : super(repaint: s._repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final scene = s.widget.scene;
    final palette = s.widget.palette;
    final pos = s.widget.frame.positions;
    final n = scene.nodeCount;
    if (n == 0 || pos.length != n * 2) return;

    s._ensureShaders(size);
    final scale = s._scale;
    final tx = s._translate.dx, ty = s._translate.dy;
    // 淡出动画期间焦点下标可能滞后于已缩小的场景，越界即视为无焦点（防越界访问）。
    final rawFocus = s._focusIndex;
    final focus = (rawFocus != null && rawFocus < n) ? rawFocus : null;
    final focusT = focus == null ? 0.0 : s._focusT;
    final rawExit = s._exitIndex;
    final exit = (rawExit != null && rawExit < n) ? rawExit : null;
    final exitT = exit == null ? 0.0 : s._exitT;

    _paintBackground(canvas, size, palette, scale, tx, ty);

    canvas.save();
    canvas.translate(tx, ty);
    canvas.scale(scale);

    final mesh = s._edgeMesh;
    if (mesh != null) {
      // BlendMode.dst = 忽略 paint、只用顶点色（见 painting.dart 的 drawVertices 文档）。
      canvas.drawVertices(
        mesh,
        .dst,
        s._paint
          ..style = .fill
          ..color = palette.edge,
      );
    }
    // 正在动的节点（进入 / 退出的焦点）从批量绘制里剔出来单独画，位置升序传入。
    final animating = <int>[
      if (exit != null) scene.orderOf[exit],
      if (focus != null) scene.orderOf[focus],
    ]..sort();
    _paintNodes(canvas, scene, palette, math.max(focusT, exitT), animating);

    // 先退后进：换选中时新焦点画在上层。
    final dimT = math.max(focusT, exitT);
    if (exit != null) {
      _paintFocus(canvas, scene, palette, exit, exitT, dimT, scale);
    }
    if (focus != null) {
      _paintFocus(canvas, scene, palette, focus, focusT, dimT, scale);
    }

    canvas.restore();

    // 标签在沉降落定后才出现（settle 动画驱动淡入）；补间期间画面只有点和线。
    final settleT = s._settleT;
    if (s.widget.showLabels && settleT > 0.01) {
      if (settleT < 1) {
        // saveLayer 只吃 alpha，RGB 被整层忽略 —— 这里不是在选颜色。
        canvas.saveLayer(
          Offset.zero & size,
          Paint()..color = Color.fromRGBO(0, 0, 0, settleT),
        );
        _paintLabels(canvas, size, scene, focus, focusT, scale, tx, ty);
        canvas.restore();
      } else {
        _paintLabels(canvas, size, scene, focus, focusT, scale, tx, ty);
      }
    }
    final vignette = s._vignetteShader;
    if (vignette != null) {
      canvas.drawRect(Offset.zero & size, Paint()..shader = vignette);
    }
  }

  void _paintBackground(
    Canvas canvas,
    Size size,
    GraphPalette palette,
    double scale,
    double tx,
    double ty,
  ) {
    final spot = s._spotShader;
    if (spot != null) {
      canvas.drawRect(Offset.zero & size, Paint()..shader = spot);
    }
    // 点阵：空间参照物。没有它，拖动一张没选中节点的图几乎没有位移反馈。
    var spacing = GraphTuning.dotSpacing;
    var step = spacing * scale;
    if (step > GraphTuning.dotMaxPx) {
      spacing = GraphTuning.dotSpacingSparse;
      step = spacing * scale;
    }
    if (step < GraphTuning.dotMinPx) return;
    final cols = (size.width / step).ceil() + 1;
    final rows = (size.height / step).ceil() + 1;
    if (cols * rows > 6000) return;
    final buf = Float32List(cols * rows * 2);
    final x0 = tx % step, y0 = ty % step;
    var k = 0;
    for (var r = 0; r < rows; r++) {
      final y = y0 + r * step;
      for (var c = 0; c < cols; c++) {
        buf[k++] = x0 + c * step;
        buf[k++] = y;
      }
    }
    canvas.drawRawPoints(
      .points,
      buf,
      s._paint
        ..color = palette.dot
        ..strokeWidth = 2
        ..strokeCap = .round
        ..style = .fill,
    );
  }

  /// 批量画节点。[skip] 是要跳过的节点在 `drawOrder` 里的位置（升序，最多两个：正在
  /// 进入与正在退出的焦点）—— 它们的实心圆半径在动，得单独画，留在批里会被整径盖住。
  void _paintNodes(
    Canvas canvas,
    GraphScene scene,
    GraphPalette palette,
    double dimT,
    List<int> skip,
  ) {
    final buf = s._nodeBuf;
    if (buf.length != scene.nodeCount * 2) return;
    final paint = s._paint
      ..strokeCap = .round
      ..style = .fill;
    // 节点 = 纯色圆，无描边（用户定调）。
    for (final b in scene.fillBatches) {
      var color = b.color;
      if (dimT > 0) {
        color = Color.lerp(color, palette.dim(color), dimT)!;
      }
      paint
        ..color = color
        ..strokeWidth = b.radius * 2;
      var from = b.start;
      for (final k in skip) {
        if (k < b.start || k >= b.end) continue;
        if (k > from) {
          canvas.drawRawPoints(
            .points,
            .sublistView(buf, from * 2, k * 2),
            paint,
          );
        }
        from = k + 1;
      }
      if (from < b.end) {
        canvas.drawRawPoints(
          .points,
          .sublistView(buf, from * 2, b.end * 2),
          paint,
        );
      }
    }
  }

  /// 聚焦态：邻域按本色画回来（保住分类身份色），选中节点自身变成**断环** ——
  /// 外径始终等于它原本的半径，缩的是里面那颗实心圆，中间空出留白。
  ///
  /// 占位不变是这套画法的全部意义：边的内缩量与未选中时一致，环压不到线，
  /// 边网格也不必跟着聚焦动画重建（[t] 只驱动这一个节点）。
  void _paintFocus(
    Canvas canvas,
    GraphScene scene,
    GraphPalette palette,
    int sel,
    double t,
    double dimT,
    double scale,
  ) {
    final pos = s.widget.frame.positions;
    final paint = s._paint..style = .fill;
    // 把这一圈邻居从「整体淡出」里捞回来。起点必须是批量绘制当前的实际颜色
    // （按 dimT 淡的），否则换选中期间新邻域会比背景还暗一档。
    for (final i in scene.neighborsOf(sel)) {
      final c = scene.colors[i];
      canvas.drawCircle(
        Offset(pos[i * 2], pos[i * 2 + 1]),
        scene.radii[i],
        paint..color = Color.lerp(Color.lerp(c, palette.dim(c), dimT)!, c, t)!,
      );
    }

    final center = Offset(pos[sel * 2], pos[sel * 2 + 1]);
    final outer = scene.radii[sel]; // 外径恒定：选中不改变这个节点的占位
    final color = scene.colors[sel];
    // 环宽有屏幕下限，不够粗时向内长；外缘钉死在 outer。
    final ringW = math.min(
      outer,
      math.max(
        GraphTuning.selectedRingWidth,
        GraphTuning.selectedRingMinPx / scale,
      ),
    );
    final core = lerpD(outer, GraphTuning.selectedCoreRadius(outer), t);

    canvas.drawCircle(
      center,
      outer - ringW / 2,
      paint
        ..style = .stroke
        ..strokeWidth = ringW
        ..color = color,
    );
    if (core > 0) {
      canvas.drawCircle(
        center,
        core,
        paint
          ..style = .fill
          ..color = color,
      );
    }
  }

  /// 标签走屏幕空间固定字号：任何缩放都清晰、glyph atlas 零重栅格；靠贪心占位防重叠，
  /// 按度数优先 —— 缩小时只剩枢纽标题，放大时逐渐铺开（地图式 LOD）。
  void _paintLabels(
    Canvas canvas,
    Size size,
    GraphScene scene,
    int? focus,
    double focusT,
    double scale,
    double tx,
    double ty,
  ) {
    final pos = s.widget.frame.positions;
    final occupied = <int>{};
    final cell = GraphTuning.labelCellPx * s._labelFactor;
    var drawn = 0;

    for (final i in scene.labelOrder) {
      if (drawn >= GraphTuning.labelMaxCount) break;
      // 选中项与 ego 中心的标签强制显示（不受占位裁剪），但样式与其它标签一致。
      final always = i == focus || i == scene.centerIndex;
      // 聚焦时只留邻域标签，其余隐藏（比整体淡出更干净）。
      if (focus != null &&
          focusT > 0.5 &&
          i != focus &&
          !scene.isNeighbor(focus, i)) {
        continue;
      }
      final sx = pos[i * 2] * scale + tx;
      final sy = pos[i * 2 + 1] * scale + ty;
      if (sx < -80 ||
          sx > size.width + 80 ||
          sy < -40 ||
          sy > size.height + 40) {
        continue;
      }
      final tp = s._labelPainter(i);
      final left = sx - tp.width / 2;
      final top = sy + scene.radii[i] * scale + 5;
      final c0 = (left / cell).floor(), c1 = ((left + tp.width) / cell).floor();
      final r0 = (top / cell).floor(), r1 = ((top + tp.height) / cell).floor();
      var blocked = false;
      for (var r = r0; r <= r1 && !blocked; r++) {
        for (var c = c0; c <= c1; c++) {
          if (occupied.contains(_cellKey(r, c))) {
            blocked = true;
            break;
          }
        }
      }
      if (blocked && !always) continue;
      for (var r = r0; r <= r1; r++) {
        for (var c = c0; c <= c1; c++) {
          occupied.add(_cellKey(r, c));
        }
      }
      tp.paint(canvas, Offset(left, top));
      drawn++;
    }
  }

  static int _cellKey(int r, int c) => ((r & 0xFFFF) << 16) | (c & 0xFFFF);

  @override
  bool shouldRepaint(covariant _GraphPainter old) => false;
}
