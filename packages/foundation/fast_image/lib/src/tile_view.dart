import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:photo_view/photo_view.dart';

import 'provider.dart';
import 'runtime.dart';
import 'rust/api/image.dart';
import 'tile_plan.dart';

part 'tile_debug.dart';

/// 看图页的原图层：铺在 `PhotoView.customChild` 里，child 尺寸 = 源图像素，所以
/// PhotoView 的 scale 就是「每源像素占几个逻辑像素」。三层叠加：
///
/// 1. overview：m 档缩略图铺满，首帧就有像素（从网格进来直接命中缓存）。
/// 2. tile：按 [FastTilePlanner] 把视口相交的 tile 交给 Rust 按 1/sample 缩放解码，解到哪画到哪。
///    粗档的 tile 不急着丢，细档没到之前它顶着，放大过程就是「模糊到清晰」。
/// 3. 兜底：不能区域解码的（progressive）用引擎解整图，最长边封顶 4096（[FastImage]）。
///
/// 内存由视口决定：可见 + 外圈预取的 tile 每块 ≤ 1MB，缓存按字节预算淘汰；文件字节和
/// 带缓存在 Rust 侧随 [FastRegionDecoder] 活着，页面 dispose 时一起释放。
class FastTileImageView extends StatefulWidget {
  /// 调试叠层开关（进程级）：画每块 tile 的边框与编号、按 sample 着色、在飞 / 排队状态，
  /// 左上角一行统计。看图页长按 ⓘ 切换。
  static final debugOverlay = ValueNotifier<bool>(false);

  /// JPEG 原图绝对路径。
  final String path;

  /// 交给 Rust 区域解码的文件；默认就是 [path]，progressive JPEG 给它的 baseline 副本。
  final String decodePath;

  /// 转正后的源图尺寸。
  final Size imageSize;

  final PhotoViewController controller;

  /// PhotoView 所在视口的逻辑尺寸。
  final Size viewportSize;

  /// 打底用的缩略图。

  final ImageProvider overview;

  /// 是不是当前页。PageView 会把邻页也装着；只有当前页开解码器、解 tile，邻页只画打底图，
  /// 切过去再开（open 是毫秒级）。不然三页各一份带缓存 + tile 缓存，内存是三倍。
  final bool active;

  const FastTileImageView({
    super.key,
    required this.path,
    String? decodePath,
    required this.imageSize,
    required this.controller,
    required this.viewportSize,
    required this.overview,
    this.active = true,
  }) : decodePath = decodePath ?? path;

  @override
  State<FastTileImageView> createState() => _FastTileImageViewState();
}

class _Tile {
  final FastTileSpec spec;
  final ui.Image image;
  final Rect covered;
  int lastUse;

  /// 第几块解出来的（调试叠层用）。
  final int order;

  _Tile({
    required this.spec,
    required this.image,
    required this.covered,
    required this.lastUse,
    required this.order,
  });

  int get bytes => image.width * image.height * 4;
}

class _FastTileImageViewState extends State<FastTileImageView> {
  /// 解出来的 tile 缓存上限（规划内的块不算，它们由 [FastTilePlanner.maxPlannedTiles] 封顶）。
  /// fit 那一层（整图 ≤ 36 块）留着，缩回去不用再画 overview 的模糊。
  static const _cacheBudgetBytes = 64 * 1024 * 1024;

  /// 一批最多解几块。可见 tile 一批全要：Rust 把它们的并集当一条带一次解出来，视口跨几行
  /// 也只跑一趟熵解码（313MB 的图一趟两三秒，按行解就是行数倍）。
  static const _batchSize = 48;

  FastRegionDecoder? _decoder;
  bool? _randomAccess;
  String _format = '';
  bool _fallback = false;
  bool _disposed = false;

  late final FastTilePlanner _planner = FastTilePlanner(
    imageSize: widget.imageSize,
  );
  FastTilePlan? _plan;
  int _planSeq = 0;
  StreamSubscription<PhotoViewControllerValue>? _sub;
  Timer? _prefetchTimer;
  Timer? _replanTimer;

  /// 超过这个像素数就不预取外圈：一批就是一趟全图熵解码，313MB 的图一趟两三秒，
  /// 预取会把用户真正要看的那一批排到后面。
  static const _prefetchMaxPixels = 50 * 1000 * 1000;

  final _tiles = <String, _Tile>{};
  final _inflight = <String>{};
  final _queue = <FastTileSpec>[];
  bool _busy = false;
  int _decoded = 0;
  int _batches = 0;
  final _repaint = ValueNotifier<int>(0);

  /// 每次 [_teardown] 加一：在飞的批回来时对不上号就丢掉。
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _sub = widget.controller.outputStateStream.listen((_) => _scheduleReplan());
    FastTileImageView.debugOverlay.addListener(_bump);
    if (widget.active) unawaited(_open());
  }

  @override
  void didUpdateWidget(FastTileImageView old) {
    super.didUpdateWidget(old);
    if (old.active == widget.active) return;
    if (widget.active) {
      unawaited(_open());
    } else {
      _teardown();
    }
  }

  void _bump() => _repaint.value++;

  Future<void> _open() async {
    if (_decoder != null || _fallback) return;
    final generation = _generation;
    try {
      final decoder = await FastRegionDecoder.open(filePath: widget.decodePath);
      if (_disposed || generation != _generation || !widget.active) {
        decoder.dispose();
        return;
      }
      _format = decoder.probe().format.name;
      _decoder = decoder;
      _replan();
      final randomAccess = await decoder.randomAccess();
      if (!_disposed && identical(_decoder, decoder)) {
        _randomAccess = randomAccess;
        if (FastTileImageView.debugOverlay.value) _bump();
      }
    } catch (e) {
      FastImageRuntime.log(
        'region decoder open failed: ${widget.decodePath} ($e)',
      );
      if (!_disposed && generation == _generation) _fail();
    }
  }

  /// tile 这条路走不通：拆掉解码器与缓存，退回引擎整解封顶的路径。
  void _fail() {
    _teardown();
    if (mounted) setState(() => _fallback = true);
  }

  /// 放掉解码器、tile 与排队；在飞的批回来时按代号丢弃。
  void _teardown() {
    _generation++;
    _replanTimer?.cancel();
    _prefetchTimer?.cancel();
    _queue.clear();
    _inflight.clear();
    _busy = false;
    for (final tile in _tiles.values) {
      tile.image.dispose();
    }
    _tiles.clear();
    _plan = null;
    _decoder?.dispose();
    _decoder = null;
    _randomAccess = null;
    if (!_disposed) _repaint.value++;
  }

  /// 捏合 / 双击动画期间 controller 每帧都在变，等它停 60ms 再规划：中间比例的那几批
  /// 解了也是白解，而每批对超大图都是一趟熵解码。
  void _scheduleReplan() {
    _replanTimer?.cancel();
    _replanTimer = Timer(const Duration(milliseconds: 60), _replan);
    // 叠层的视口框与 HUD 跟着手势走；不开叠层时手势期间一帧都不重画（层由合成器变换）。
    if (FastTileImageView.debugOverlay.value) _repaint.value++;
  }

  @override
  void dispose() {
    _disposed = true;
    FastTileImageView.debugOverlay.removeListener(_bump);
    _sub?.cancel();
    _teardown();
    _repaint.dispose();
    super.dispose();
  }

  /// 视口在源像素坐标里的矩形。PhotoView 把 child 居中后按 scale 绕视口中心缩放、再平移
  /// position：视口点 v ↔ child 点 c 满足 v = 视口中心 + position + (c − child/2) × scale。
  Rect? _visibleSource() {
    final value = widget.controller.value;
    final scale = value.scale;
    if (scale == null || scale <= 0) return null;
    final viewport = widget.viewportSize;
    final center =
        Offset(viewport.width / 2, viewport.height / 2) + value.position;
    final half = Offset(
      widget.imageSize.width / 2,
      widget.imageSize.height / 2,
    );
    Offset toChild(Offset v) => (v - center) / scale + half;
    final a = toChild(Offset.zero);
    final b = toChild(Offset(viewport.width, viewport.height));
    return Rect.fromPoints(a, b);
  }

  void _replan() {
    if (_decoder == null || _disposed) return;
    final visible = _visibleSource();
    final scale = widget.controller.value.scale;
    if (visible == null || scale == null) return;
    final physicalScale = scale * MediaQuery.devicePixelRatioOf(context);
    final plan = _planner.plan(visible: visible, physicalScale: physicalScale);
    _plan = plan;
    _planSeq++;

    final wanted = <String>{
      for (final t in plan.visible) t.key,
      for (final t in plan.prefetch) t.key,
    };
    for (final key in wanted) {
      _tiles[key]?.lastUse = _planSeq;
    }
    _evict(keep: wanted);

    _queue
      ..clear()
      ..addAll(plan.visible.where(_missing));
    _pump();

    _prefetchTimer?.cancel();
    final pixels = widget.imageSize.width * widget.imageSize.height;
    if (pixels > _prefetchMaxPixels) {
      _repaint.value++;
      return;
    }
    _prefetchTimer = Timer(const Duration(milliseconds: 90), () {
      if (_disposed || !identical(_plan, plan)) return;
      _queue.addAll(plan.prefetch.where(_missing));
      _pump();
    });
    _repaint.value++;
  }

  bool _missing(FastTileSpec spec) =>
      !_tiles.containsKey(spec.key) && !_inflight.contains(spec.key);

  void _evict({required Set<String> keep}) {
    var total = _tiles.values.fold(0, (n, t) => n + t.bytes);
    if (total <= _cacheBudgetBytes) return;
    final victims =
        _tiles.values.where((t) => !keep.contains(t.spec.key)).toList()
          ..sort((a, b) => a.lastUse.compareTo(b.lastUse));
    for (final tile in victims) {
      if (total <= _cacheBudgetBytes) break;
      _tiles.remove(tile.spec.key);
      tile.image.dispose();
      total -= tile.bytes;
    }
  }

  /// 一次只跑一批：带在 Rust 侧共享，串行才能让后一批命中前一批解出的带。
  void _pump() {
    if (_busy) return;
    final batch = <FastTileSpec>[];
    while (_queue.isNotEmpty && batch.length < _batchSize) {
      final spec = _queue.removeAt(0);
      if (!_missing(spec)) continue;
      if (batch.isNotEmpty && spec.sample != batch.first.sample) {
        _queue.insert(0, spec);
        break;
      }
      _inflight.add(spec.key);
      batch.add(spec);
    }
    if (batch.isEmpty) return;
    _busy = true;
    _batches++;
    _repaint.value++;
    unawaited(_decodeBatch(batch));
  }

  bool _stillWanted(FastTileSpec spec) {
    final plan = _plan;
    if (plan == null || spec.sample != plan.sample) return false;
    return plan.visible.any((t) => t.key == spec.key) ||
        plan.prefetch.any((t) => t.key == spec.key);
  }

  Future<void> _decodeBatch(List<FastTileSpec> batch) async {
    final generation = _generation;
    var failed = false;
    try {
      final decoder = _decoder;
      if (decoder == null || _disposed) return;
      final results = await decoder.decodeTiles(
        rects: [
          for (final spec in batch)
            FastTileRect(
              x: spec.sourceRect.left.floor(),
              y: spec.sourceRect.top.floor(),
              width: spec.sourceRect.width.ceil(),
              height: spec.sourceRect.height.ceil(),
            ),
        ],
        denom: batch.first.sample,
      );
      if (_disposed || generation != _generation) return;
      // 一批的位图并行上传，不逐块 await；一块失败其余的也释放。
      final images = await Future.wait([
        for (var i = 0; i < batch.length && i < results.length; i++)
          _toImage(results[i]),
      ], cleanUp: (image) => image.dispose());
      final stale = _disposed || generation != _generation;
      // Rust 会跳过落在图外的矩形，结果按覆盖矩形对号，不按下标。
      final pending = batch.toList();
      for (var i = 0; i < images.length; i++) {
        final pixels = results[i];
        final image = images[i];
        final covered = Rect.fromLTWH(
          pixels.x.toDouble(),
          pixels.y.toDouble(),
          pixels.width.toDouble(),
          pixels.height.toDouble(),
        );
        final at = pending.indexWhere(
          (s) =>
              covered.contains(s.sourceRect.topLeft + const Offset(0.5, 0.5)),
        );
        if (at < 0) {
          image.dispose();
          continue;
        }
        final spec = pending.removeAt(at);
        if (stale || !_stillWanted(spec)) {
          image.dispose();
          continue;
        }
        _tiles[spec.key] = _Tile(
          spec: spec,
          image: image,
          covered: covered,
          lastUse: _planSeq,
          order: ++_decoded,
        );
        _repaint.value++;
      }
      // 插入后再按预算淘汰一次：规划里的块不动，动的是上一档留下的。
      final plan = _plan;
      if (!stale && plan != null) {
        _evict(
          keep: {
            for (final t in plan.visible) t.key,
            for (final t in plan.prefetch) t.key,
          },
        );
      }
    } catch (e) {
      failed = true;
      FastImageRuntime.log(
        'tile batch decode failed: ${batch.length} tiles ($e)',
      );
    } finally {
      if (generation == _generation) {
        for (final spec in batch) {
          _inflight.remove(spec.key);
        }
        _busy = false;
        // 一块都没解出来就失败：这个文件在 Rust 那边解不动，别一批批地撞。
        if (failed && _decoded == 0 && !_disposed) {
          _fail();
        } else if (!_disposed) {
          _pump();
        }
      }
    }
  }

  /// RGBA 进引擎。不用 `decodeImageFromPixels`：它失败时回调永远不来，这里的批就永远
  /// 等不到。这条链每一步都是 Future，错会抛出来。
  static Future<ui.Image> _toImage(FastTilePixels pixels) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(pixels.rgba);
    try {
      final descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: pixels.pixelWidth,
        height: pixels.pixelHeight,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      try {
        final codec = await descriptor.instantiateCodec();
        try {
          return (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: .expand,
      children: [
        Image(
          image: widget.overview,
          fit: .fill,
          filterQuality: .low,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
        if (_fallback)
          Image(
            image: FastImage(widget.path),
            fit: .fill,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          )
        else
          // 自成一层：PhotoView 每帧重建、变换由合成器套在层上，tile 只在有新块时重画。
          RepaintBoundary(
            child: CustomPaint(
              painter: _TilePainter(
                tiles: _tiles,
                visible: _visibleSource,
                repaint: _repaint,
                labelStyle: DefaultTextStyle.of(context).style,
                debug: () => FastTileImageView.debugOverlay.value
                    ? _DebugSnapshot(
                        plan: _plan,
                        inflight: _inflight,
                        queued: {for (final t in _queue) t.key},
                        scale: widget.controller.value.scale ?? 1,
                        randomAccess: _randomAccess,
                        format: _format,
                        batches: _batches,
                        decoded: _decoded,
                        cacheBytes: _tiles.values.fold(
                          0,
                          (n, t) => n + t.bytes,
                        ),
                      )
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _TilePainter extends CustomPainter {
  final Map<String, _Tile> tiles;
  final Rect? Function() visible;
  final _DebugSnapshot? Function() debug;
  final TextStyle labelStyle;

  _TilePainter({
    required this.tiles,
    required this.visible,
    required this.debug,
    required this.labelStyle,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = visible() ?? (Offset.zero & size);
    // 全部缓存的 tile 都画（≤ 48MB、几十块，GPU 不在乎），不按视口裁：这一层只在有新块时
    // 重画，平移时不重画，裁了就会露白。粗档先画、细档盖在上面：换档过程中旧 tile 顶着。
    final order = tiles.values.toList()
      ..sort((a, b) => b.spec.sample.compareTo(a.spec.sample));
    final paint = Paint()..filterQuality = .medium;
    for (final tile in order) {
      final image = tile.image;
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        tile.covered,
        paint,
      );
    }
    final snapshot = debug();
    if (snapshot != null) _paintDebug(canvas, rect, order, snapshot);
  }

  /// 重画只由 [repaint] 通知驱动：PhotoView 每帧重建会换一个 painter 实例，这里回 false，
  /// 手势期间层不重画，变换由合成器套在层上。
  @override
  bool shouldRepaint(_TilePainter oldDelegate) => false;
}
