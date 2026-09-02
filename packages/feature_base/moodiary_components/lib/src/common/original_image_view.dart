import 'dart:async';
import 'dart:ui' as ui;

import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_rust/foundation.dart' as rust;
import 'package:mui/mui.dart';
import 'package:photo_view/photo_view.dart';

import 'tile_plan.dart';

part 'original_image_debug.dart';

/// 看图页的原图层：铺在 `PhotoView.customChild` 里，child 尺寸 = 源图像素，所以
/// PhotoView 的 scale 就是「每源像素占几个逻辑像素」。三层叠加：
///
/// 1. overview：m 档缩略图铺满，首帧就有像素（从网格进来直接命中缓存）。
/// 2. tile：按 [TilePlanner] 把视口相交的 tile 交给 Rust 按 1/sample 缩放解码，解到哪画到哪。
///    粗档的 tile 不急着丢，细档没到之前它顶着，放大过程就是「模糊到清晰」。
/// 3. 兜底：不能区域解码的（progressive）用引擎解整图，最长边封顶 4096（[MediaImage]）。
///
/// 内存由视口决定：可见 + 外圈预取的 tile 每块 ≤ 1MB，缓存按字节预算淘汰；文件字节和
/// 带缓存在 Rust 侧随 [rust.JpegRegionDecoder] 活着，页面 dispose 时一起释放。
class OriginalImageView extends StatefulWidget {
  /// 调试叠层开关（进程级）：画每块 tile 的边框与编号、按 sample 着色、在飞 / 排队状态，
  /// 左上角一行统计。看图页长按 ⓘ 切换。
  static final debugOverlay = ValueNotifier<bool>(false);

  /// JPEG 原图绝对路径。
  final String path;

  /// 转正后的源图尺寸。
  final Size imageSize;

  final PhotoViewController controller;

  /// PhotoView 所在视口的逻辑尺寸。
  final Size viewportSize;

  /// 打底用的缩略图。
  final ImageProvider overview;

  const OriginalImageView({
    super.key,
    required this.path,
    required this.imageSize,
    required this.controller,
    required this.viewportSize,
    required this.overview,
  });

  @override
  State<OriginalImageView> createState() => _OriginalImageViewState();
}

class _Tile {
  final TileSpec spec;
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

class _OriginalImageViewState extends State<OriginalImageView> {
  /// 解出来的 tile 缓存上限：64 个 512² 的 RGBA。fit 那一层（整图 ≤ 36 块）留着，缩回去
  /// 不用再画 overview 的模糊。
  static const _cacheBudgetBytes = 64 * 1024 * 1024;

  /// 一批最多解几块。可见 tile 一批全要：Rust 把它们的并集当一条带一次解出来，视口跨几行
  /// 也只跑一趟熵解码（313MB 的图一趟两三秒，按行解就是行数倍）。
  static const _batchSize = 48;

  rust.JpegRegionDecoder? _decoder;
  bool? _randomAccess;
  bool _fallback = false;
  bool _disposed = false;

  late final TilePlanner _planner = TilePlanner(imageSize: widget.imageSize);
  TilePlan? _plan;
  int _planSeq = 0;
  StreamSubscription<PhotoViewControllerValue>? _sub;
  Timer? _prefetchTimer;
  Timer? _replanTimer;

  /// 超过这个像素数就不预取外圈：一批就是一趟全图熵解码，313MB 的图一趟两三秒，
  /// 预取会把用户真正要看的那一批排到后面。
  static const _prefetchMaxPixels = 50 * 1000 * 1000;

  final _tiles = <String, _Tile>{};
  final _inflight = <String>{};
  final _queue = <TileSpec>[];
  bool _busy = false;
  int _decoded = 0;
  int _batches = 0;
  final _repaint = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _sub = widget.controller.outputStateStream.listen((_) => _scheduleReplan());
    OriginalImageView.debugOverlay.addListener(_bump);
    unawaited(_open());
  }

  void _bump() => _repaint.value++;

  Future<void> _open() async {
    try {
      final decoder = await rust.JpegRegionDecoder.open(filePath: widget.path);
      if (_disposed) {
        decoder.dispose();
        return;
      }
      final probe = decoder.probe();
      if (!probe.regionDecodable) {
        decoder.dispose();
        setState(() => _fallback = true);
        return;
      }
      _decoder = decoder;
      _replan();
      final randomAccess = await decoder.randomAccess();
      if (!_disposed && identical(_decoder, decoder)) {
        _randomAccess = randomAccess;
        if (OriginalImageView.debugOverlay.value) _bump();
      }
    } catch (e) {
      logger.d('region decoder open failed: ${widget.path} ($e)');
      if (mounted) setState(() => _fallback = true);
    }
  }

  /// 捏合 / 双击动画期间 controller 每帧都在变，等它停 100ms 再规划：中间比例的那几批
  /// 解了也是白解，而每批对超大图都是一趟熵解码。
  void _scheduleReplan() {
    _replanTimer?.cancel();
    _replanTimer = Timer(const Duration(milliseconds: 60), _replan);
    // 叠层的视口框与 HUD 跟着手势走；不开叠层时手势期间一帧都不重画（层由合成器变换）。
    if (OriginalImageView.debugOverlay.value) _repaint.value++;
  }

  @override
  void dispose() {
    _disposed = true;
    OriginalImageView.debugOverlay.removeListener(_bump);
    _sub?.cancel();
    _replanTimer?.cancel();
    _prefetchTimer?.cancel();
    _queue.clear();
    for (final tile in _tiles.values) {
      tile.image.dispose();
    }
    _tiles.clear();
    _decoder?.dispose();
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

  bool _missing(TileSpec spec) =>
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
    final batch = <TileSpec>[];
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

  bool _stillWanted(TileSpec spec) {
    final plan = _plan;
    if (plan == null || spec.sample != plan.sample) return false;
    return plan.visible.any((t) => t.key == spec.key) ||
        plan.prefetch.any((t) => t.key == spec.key);
  }

  Future<void> _decodeBatch(List<TileSpec> batch) async {
    try {
      final decoder = _decoder;
      if (decoder == null || _disposed) return;
      final results = await decoder.decodeTiles(
        rects: [
          for (final spec in batch)
            rust.TileRect(
              x: spec.sourceRect.left.floor(),
              y: spec.sourceRect.top.floor(),
              width: spec.sourceRect.width.ceil(),
              height: spec.sourceRect.height.ceil(),
            ),
        ],
        denom: batch.first.sample,
      );
      if (_disposed) return;
      // 一批的位图并行上传，不逐块 await。
      final images = await Future.wait([
        for (var i = 0; i < batch.length && i < results.length; i++)
          _toImage(results[i]),
      ]);
      for (var i = 0; i < images.length; i++) {
        final spec = batch[i];
        final pixels = results[i];
        final image = images[i];
        if (_disposed || !_stillWanted(spec)) {
          image.dispose();
          continue;
        }
        _tiles[spec.key] = _Tile(
          spec: spec,
          image: image,
          covered: Rect.fromLTWH(
            pixels.x.toDouble(),
            pixels.y.toDouble(),
            pixels.width.toDouble(),
            pixels.height.toDouble(),
          ),
          lastUse: _planSeq,
          order: ++_decoded,
        );
        _repaint.value++;
      }
    } catch (e) {
      logger.d('tile batch decode failed: ${batch.length} tiles ($e)');
    } finally {
      for (final spec in batch) {
        _inflight.remove(spec.key);
      }
      _busy = false;
      if (!_disposed) _pump();
    }
  }

  static Future<ui.Image> _toImage(rust.TilePixels pixels) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels.rgba,
      pixels.pixelWidth,
      pixels.pixelHeight,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
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
            image: MediaImage(widget.path),
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
                labelStyle: context.theme.typography.labelMedium.onSurface,
                debug: () => OriginalImageView.debugOverlay.value
                    ? _DebugSnapshot(
                        plan: _plan,
                        inflight: _inflight,
                        queued: {for (final t in _queue) t.key},
                        scale: widget.controller.value.scale ?? 1,
                        randomAccess: _randomAccess,
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
