import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui show Vertices;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:moodiary_diary/src/presentation/graph/graph_scene.dart';
import 'package:moodiary_diary/src/presentation/graph/graph_style.dart';
import 'package:mui/mui.dart';

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

class GraphCanvas extends StatefulWidget {
  final GraphScene scene;
  final GraphFrame frame;
  final GraphPalette palette;
  final int? selected;
  final ValueChanged<int?> onSelect;
  final bool showLabels;
  final GraphCanvasController? controller;

  final List<EgoDirection?>? egoDirections;

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
  double _scale = 1;
  Offset _translate = .zero;
  bool _autoFit = true;
  Size _viewport = .zero;

  double _startScale = 1;
  Offset _startTranslate = .zero;
  Offset _startFocal = .zero;

  Float32List _nodeBuf = Float32List(0);
  ui.Vertices? _edgeMesh;

  late final AnimationController _focusCtl;
  late final AnimationController _exitCtl;
  late final AnimationController _settleCtl;
  late final AnimationController _cameraCtl;
  Ticker? _fling;
  Offset _flingVelocity = .zero;
  double _camFromScale = 1, _camToScale = 1;
  Offset _camFromT = .zero, _camToT = .zero;

  int? _focusIndex;

  int? _exitIndex;

  final _repaint = ValueNotifier<int>(0);

  final _paint = Paint()..isAntiAlias = true;
  Shader? _spotShader;
  Shader? _vignetteShader;
  Size _shaderSize = .zero;

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
      if (old.scene.nodeCount != widget.scene.nodeCount) {
        _autoFit = true;
        widget.controller?._setMoved(false);
        _stopFling();
        _cameraCtl.stop();
      }
      if (!widget.frame.settled) _settleCtl.value = 0;
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

  void _onSettleTick() => _bump();

  void _onFrame() {
    if (widget.frame.settled) {
      if (_settleT < 1) _settleCtl.forward();
    } else if (_settleCtl.value != 0) {
      _settleCtl
        ..stop()
        ..value = 0;
    }
    _rebuildBuffers();
    if (_autoFit && !_viewport.isEmpty) _fitCamera(_viewport);
    _bump();
  }

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
      if (a == center) return palette.outgoing.withValues(alpha: 0.8);
      if (b == center) return palette.incoming.withValues(alpha: 0.8);
    }
    return palette.edge;
  }

  void _rebuildEdgeMesh() {
    final scene = widget.scene;
    final pos = widget.frame.positions;
    final ec = scene.edgeCount;
    if (ec == 0 || pos.length != scene.nodeCount * 2) {
      _edgeMesh?.dispose();
      _edgeMesh = null;
      return;
    }
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
          base = scene.colors[a];
          width = GraphTuning.edgeWidthHi;
        } else {
          base = palette.dimEdge(base);
        }
      }

      final rawAx = pos[a * 2], rawAy = pos[a * 2 + 1];
      final rawBx = pos[b * 2], rawBy = pos[b * 2 + 1];
      final dx = rawBx - rawAx, dy = rawBy - rawAy;
      final len = math.sqrt(dx * dx + dy * dy);
      final headLen = 2.4 + radii[b] * 0.24;
      final halfW = headLen * 0.38;
      final trimA = radii[a] + 1.0, trimB = radii[b] + 1.5;
      if (!len.isFinite || len <= trimA + trimB + headLen + 2) {
        v += 9;
        continue;
      }
      final ux = dx / len, uy = dy / len;
      final ax = rawAx + ux * trimA, ay = rawAy + uy * trimA;
      final tipX = rawBx - ux * trimB, tipY = rawBy - uy * trimB;
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

  // 不用 indices：规避 Vertices 顶点索引的 Uint16 上限
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

  void _fitCamera(Size size) {
    final pos = widget.frame.positions;
    final n = widget.scene.nodeCount;
    if (pos.length != n * 2 || n == 0 || size.isEmpty) return;
    final extent = widget.preferredExtent;
    if (extent != null && extent > 0) {
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
            color: widget.palette.label,
            fontSize: GraphTuning.labelSize * _labelFactor,
            height: 1.1,
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
      _shaderSize = .zero;
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
      // BlendMode.dst：忽略 paint，只用顶点色
      canvas.drawVertices(
        mesh,
        .dst,
        s._paint
          ..style = .fill
          ..color = palette.edge,
      );
    }
    final animating = <int>[
      if (exit != null) scene.orderOf[exit],
      if (focus != null) scene.orderOf[focus],
    ]..sort();
    _paintNodes(canvas, scene, palette, math.max(focusT, exitT), animating);

    final dimT = math.max(focusT, exitT);
    if (exit != null) {
      _paintFocus(canvas, scene, palette, exit, exitT, dimT, scale);
    }
    if (focus != null) {
      _paintFocus(canvas, scene, palette, focus, focusT, dimT, scale);
    }

    canvas.restore();

    final settleT = s._settleT;
    if (s.widget.showLabels && settleT > 0.01) {
      if (settleT < 1) {
        // saveLayer 的 paint 只取 alpha，RGB 被忽略
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
    for (final i in scene.neighborsOf(sel)) {
      final c = scene.colors[i];
      canvas.drawCircle(
        Offset(pos[i * 2], pos[i * 2 + 1]),
        scene.radii[i],
        paint..color = Color.lerp(Color.lerp(c, palette.dim(c), dimT)!, c, t)!,
      );
    }

    final center = Offset(pos[sel * 2], pos[sel * 2 + 1]);
    final outer = scene.radii[sel];
    final color = scene.colors[sel];
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
      final always = i == focus || i == scene.centerIndex;
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
