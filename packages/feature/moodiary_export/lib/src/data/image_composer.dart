import 'dart:io';
import 'dart:ui' as ui;

import 'package:fast_image/fast_image.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:moodiary_components/moodiary_components.dart' show MoodiaryLogo;
import 'package:moodiary_logging/moodiary_logging.dart';

import '../presentation/image_card/card.dart';
import '../presentation/image_card/card_style.dart';
import 'export_doc.dart';
import 'export_options.dart';

class ImageComposeResult {
  final String path;
  final int widthPx;
  final int heightPx;

  final int skippedImages;

  const ImageComposeResult({
    required this.path,
    required this.widthPx,
    required this.heightPx,
    this.skippedImages = 0,
  });
}

abstract final class ImageComposer {
  // 2000 × 3 倍 = 6000 物理像素，稳在纹理上限内
  static const double _kBandLogicalHeight = 2000;

  static const double _kDowngradeAboveLogical = 60000;

  static const int _kMaxPreviewScale = 3;

  static const int _kPreviewPixelBudget = 12 * 1000 * 1000;

  static Future<ImageComposeResult> composeToFile({
    required List<ExportDoc> docs,
    required ExportCommon common,
    required ImageExportOptions options,
    required ImageCardStyle style,
    required String outPath,
    bool Function()? isCancelled,
    void Function(int band, int total)? onProgress,
  }) async {
    final decoded = await _decodeImages(
      docs,
      common,
      (style.contentWidth * options.scale).round(),
    );
    try {
      var scale = options.scale;
      var brand = await _brandMark(style, scale);
      _Composition composition = await _Composition.layout(
        docs: docs,
        common: common,
        style: style,
        images: decoded.images,
        brand: brand,
        scale: scale,
      );
      while (composition.contentHeight > _kDowngradeAboveLogical && scale > 1) {
        composition.dispose();
        scale -= 1;
        logger.d('image export: content too tall, downgrading scale to $scale');
        brand = await _brandMark(style, scale);
        composition = await _Composition.layout(
          docs: docs,
          common: common,
          style: style,
          images: decoded.images,
          brand: brand,
          scale: scale,
        );
      }

      try {
        final totalLogical = composition.contentHeight.ceil();
        final widthPx = (style.widthDp * scale).round();
        final heightPx = totalLogical * scale;
        final bands = _bands(totalLogical);

        final writer = await FastPngWriter.create(
          outputPath: outPath,
          width: widthPx,
          height: heightPx,
        );
        for (var i = 0; i < bands.length; i++) {
          if (isCancelled?.call() ?? false) {
            await File(outPath).delete().catchError((_) => File(outPath));
            throw const _ImageComposeCancelled();
          }
          final band = bands[i];
          final image = await composition.band(band.$1, band.$2);
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            if (bytes == null) {
              throw StateError('toByteData returned null for band $i');
            }
            await writer.push(rgba: bytes.buffer.asUint8List());
          } finally {
            image.dispose();
          }
          onProgress?.call(i + 1, bands.length);
        }
        await writer.finish();
        return ImageComposeResult(
          path: outPath,
          widthPx: widthPx,
          heightPx: heightPx,
          skippedImages: decoded.skipped,
        );
      } finally {
        composition.dispose();
      }
    } finally {
      for (final image in decoded.images.values) {
        image.dispose();
      }
    }
  }

  static Future<ImagePreviewBands> renderBands({
    required List<ExportDoc> docs,
    required ExportCommon common,
    required ImageCardStyle style,
    required double devicePixelRatio,
  }) async {
    final maxScale = devicePixelRatio.ceil().clamp(1, _kMaxPreviewScale);
    final decoded = await _decodeImages(
      docs,
      common,
      (style.contentWidth * maxScale).round(),
    );
    final brand = await _brandMark(style, maxScale);
    final composition = await _Composition.layout(
      docs: docs,
      common: common,
      style: style,
      images: decoded.images,
      brand: brand,
      scale: maxScale,
    );
    try {
      final logicalHeight = composition.contentHeight;
      final scale = _previewScale(
        logicalHeight: logicalHeight,
        widthDp: style.widthDp,
        maxScale: maxScale,
      );
      final out = <ui.Image>[];
      for (final band in _bands(logicalHeight.ceil())) {
        out.add(await composition.band(band.$1, band.$2, ratio: scale));
      }
      return ImagePreviewBands(
        bands: out,
        logicalHeight: logicalHeight,
        scale: scale,
      );
    } finally {
      composition.dispose();
      for (final image in decoded.images.values) {
        image.dispose();
      }
    }
  }

  static int _previewScale({
    required double logicalHeight,
    required double widthDp,
    required int maxScale,
  }) {
    for (var scale = maxScale; scale > 1; scale--) {
      final pixels = widthDp * scale * logicalHeight * scale;
      if (pixels <= _kPreviewPixelBudget) return scale;
    }
    return 1;
  }

  static Future<ui.Image?> _brandMark(ImageCardStyle style, int scale) =>
      style.watermark
      ? MoodiaryLogo.rasterize(
          brightness: style.brightness,
          pixels: (kBrandMarkSize * scale).round(),
        )
      : Future.value();

  static List<(double, double)> _bands(int totalLogical) =>
      imageBands(totalLogical, _kBandLogicalHeight.toInt());

  // 离屏树不跑第二帧，Image.file 异步 resolve 来不及，必须先解成 ui.Image
  static Future<_DecodedImages> _decodeImages(
    List<ExportDoc> docs,
    ExportCommon common,
    int targetWidth,
  ) async {
    if (common.media == ExportMediaPolicy.none) {
      return const _DecodedImages({}, 0);
    }
    final paths = <String>{};
    void walk(List<IrBlock> blocks) {
      for (final block in blocks) {
        switch (block) {
          case IrBlock_Image(:final path, :final isExternal):
            if (!isExternal && common.media == ExportMediaPolicy.embed) {
              paths.add(path);
            }
          case IrBlock_Media(:final coverPath):
            if (coverPath != null && common.media == ExportMediaPolicy.embed) {
              paths.add(coverPath);
            }
          case IrBlock_Quote(:final children):
            walk(children);
          case IrBlock_List(:final items):
            for (final item in items) {
              walk(item.children);
            }
          case IrBlock_Table(:final rows):
            for (final row in rows) {
              for (final cell in row.cells) {
                walk(cell.children);
              }
            }
          default:
            break;
        }
      }
    }

    for (final doc in docs) {
      walk(doc.blocks);
    }

    final images = <String, ui.Image>{};
    var skipped = 0;
    for (final path in paths) {
      try {
        final bytes = await File(path).readAsBytes();
        final codec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: targetWidth,
        );
        final frame = await codec.getNextFrame();
        codec.dispose();
        images[path] = frame.image;
      } catch (e) {
        logger.d('image export: skip $path ($e)');
        skipped++;
      }
    }
    return _DecodedImages(images, skipped);
  }
}

class _DecodedImages {
  final Map<String, ui.Image> images;
  final int skipped;

  const _DecodedImages(this.images, this.skipped);
}

class _ImageComposeCancelled implements Exception {
  const _ImageComposeCancelled();

  @override
  String toString() => 'ImageComposeCancelled';
}

class _Composition {
  final _BandController _controller;
  final RenderView _renderView;
  final PipelineOwner _pipelineOwner;
  final RenderRepaintBoundary _boundary;
  final int scale;

  _Composition._(
    this._controller,
    this._renderView,
    this._pipelineOwner,
    this._boundary,
    this.scale,
  );

  double get contentHeight => _controller.contentHeight;

  static Future<_Composition> layout({
    required List<ExportDoc> docs,
    required ExportCommon common,
    required ImageCardStyle style,
    required Map<String, ui.Image> images,
    required ui.Image? brand,
    required int scale,
  }) async {
    final view = ui.PlatformDispatcher.instance.implicitView;
    if (view == null) {
      throw StateError('no implicit view: cannot rasterise offscreen');
    }

    final controller = _BandController();
    final boundary = RenderRepaintBoundary();
    final renderView = RenderView(
      view: view,
      child: boundary,
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tightFor(width: style.widthDp),
        physicalConstraints: BoxConstraints.tightFor(
          width: style.widthDp * scale,
        ),
        devicePixelRatio: scale.toDouble(),
      ),
    );
    final pipelineOwner = PipelineOwner()..rootNode = renderView;
    renderView.prepareInitialFrame();

    final buildOwner = BuildOwner(focusManager: FocusManager());
    final element = RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
      child: _BandView(
        controller: controller,
        background: style.background,
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.noScaling),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: ImageCard(
              docs: docs,
              common: common,
              style: style,
              images: images,
              brand: brand,
            ),
          ),
        ),
      ),
    ).attachToRenderTree(buildOwner);

    buildOwner
      ..buildScope(element)
      ..finalizeTree();
    pipelineOwner
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();

    return _Composition._(
      controller,
      renderView,
      pipelineOwner,
      boundary,
      scale,
    );
  }

  Future<ui.Image> band(double offset, double height, {int? ratio}) async {
    _controller.moveTo(offset: offset, height: height);
    _pipelineOwner
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();
    return _boundary.toImage(pixelRatio: (ratio ?? scale).toDouble());
  }

  void dispose() {
    _pipelineOwner.rootNode = null;
    _renderView.dispose();
  }
}

class _BandController extends ChangeNotifier {
  double offset = 0;
  double height = ImageComposer._kBandLogicalHeight;
  double contentHeight = 0;

  void moveTo({required double offset, required double height}) {
    if (this.offset == offset && this.height == height) return;
    this.offset = offset;
    this.height = height;
    notifyListeners();
  }
}

class _BandView extends SingleChildRenderObjectWidget {
  final _BandController controller;
  final Color background;

  const _BandView({
    required this.controller,
    required this.background,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBand(controller: controller, background: background);

  @override
  void updateRenderObject(BuildContext context, _RenderBand renderObject) {
    renderObject
      ..controller = controller
      ..background = background;
  }
}

class _RenderBand extends RenderBox with RenderObjectWithChildMixin<RenderBox> {
  _RenderBand({required this._controller, required this._background}) {
    _controller.addListener(_onBandChanged);
  }

  _BandController _controller;
  Color _background;
  double _lastHeight = 0;

  set controller(_BandController value) {
    if (identical(_controller, value)) return;
    _controller.removeListener(_onBandChanged);
    _controller = value..addListener(_onBandChanged);
    markNeedsLayout();
  }

  set background(Color value) {
    if (_background == value) return;
    _background = value;
    markNeedsPaint();
  }

  void _onBandChanged() {
    if (_controller.height != _lastHeight) {
      markNeedsLayout();
    } else {
      markNeedsPaint();
    }
  }

  @override
  void detach() {
    _controller.removeListener(_onBandChanged);
    super.detach();
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    child!.layout(
      BoxConstraints(minWidth: width, maxWidth: width),
      parentUsesSize: true,
    );
    _controller.contentHeight = child!.size.height;
    _lastHeight = _controller.height;
    size = Size(width, _controller.height);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // 先铺底：ceil 的余数会让末带下沿超出内容高度，留下透明缝
    context.canvas.drawRect(offset & size, Paint()..color = _background);
    context.pushClipRect(needsCompositing, offset, Offset.zero & size, (
      inner,
      innerOffset,
    ) {
      inner.paintChild(child!, innerOffset.translate(0, -_controller.offset));
    });
  }
}

@visibleForTesting
List<(double, double)> imageBands(int totalLogical, int bandHeight) {
  final bands = <(double, double)>[];
  var offset = 0;
  while (offset < totalLogical) {
    final height = (totalLogical - offset).clamp(1, bandHeight);
    bands.add((offset.toDouble(), height.toDouble()));
    offset += height;
  }
  if (bands.isEmpty) bands.add((0, 1));
  return bands;
}

class ImagePreviewBands {
  final List<ui.Image> bands;
  final double logicalHeight;

  final int scale;

  const ImagePreviewBands({
    required this.bands,
    required this.logicalHeight,
    required this.scale,
  });

  void dispose() {
    for (final band in bands) {
      band.dispose();
    }
  }
}
