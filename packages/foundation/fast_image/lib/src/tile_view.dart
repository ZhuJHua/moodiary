import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:photo_view/photo_view.dart';

import 'provider.dart';
import 'runtime.dart';
import 'rust/api/image.dart';
import 'tile_plan.dart';

part 'tile_debug.dart';

class FastTileImageView extends StatefulWidget {
  static final debugOverlay = ValueNotifier<bool>(false);

  final String path;

  final String decodePath;

  final Size imageSize;

  final PhotoViewController controller;

  final Size viewportSize;

  final ImageProvider overview;

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
  static const _cacheBudgetBytes = 64 * 1024 * 1024;

  static const _uploadChunk = 12;

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

  static const _prefetchMaxPixels = 50 * 1000 * 1000;

  final _tiles = <String, _Tile>{};
  final _inflight = <String>{};
  final _queue = <FastTileSpec>[];
  bool _busy = false;
  int _decoded = 0;
  int _batches = 0;
  final _repaint = ValueNotifier<int>(0);

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

  void _fail() {
    _teardown();
    if (mounted) setState(() => _fallback = true);
  }

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

  void _scheduleReplan() {
    _replanTimer?.cancel();
    _replanTimer = Timer(const Duration(milliseconds: 60), _replan);
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
      final images = <ui.Image>[];
      final count = math.min(batch.length, results.length);
      try {
        for (var start = 0; start < count; start += _uploadChunk) {
          if (start > 0) await Future<void>.delayed(Duration.zero);
          images.addAll(
            await Future.wait([
              for (
                var i = start;
                i < math.min(start + _uploadChunk, count);
                i++
              )
                _toImage(results[i]),
            ], cleanUp: (image) => image.dispose()),
          );
        }
      } catch (_) {
        for (final image in images) {
          image.dispose();
        }
        rethrow;
      }
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
        if (failed && _decoded == 0 && !_disposed) {
          _fail();
        } else if (!_disposed) {
          _pump();
        }
      }
    }
  }

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
    // 不按视口裁：这层只在有新块时重画，裁了平移会露白；粗档先画、细档盖在上面
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

  @override
  bool shouldRepaint(_TilePainter oldDelegate) => false;
}
