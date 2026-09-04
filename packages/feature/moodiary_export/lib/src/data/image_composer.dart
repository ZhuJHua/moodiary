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

/// 一次出图的结果。
class ImageComposeResult {
  final String path;
  final int widthPx;
  final int heightPx;

  /// 解不出来被跳过的图片数（文件没了 / 格式坏了）。
  final int skippedImages;

  const ImageComposeResult({
    required this.path,
    required this.widthPx,
    required this.heightPx,
    this.skippedImages = 0,
  });
}

/// IR → 一张长 PNG。
///
/// **不截 WebView**：`RenderRepaintBoundary.toImage()` 只光栅化 Flutter 自己的图层树，
/// 平台视图（Android hybrid/TLHC、iOS `UIKitView`）不在其中，截出来是空白。所以图片这条
/// 和 md / docx / pdf 一样吃 [ExportDoc] 的 IR，自己画一棵树。
///
/// **产物永远是一张图**，高度不设上限。分带只是实现细节：`toImage` 走 GPU 光栅化，单边
/// 受纹理上限约束（多数设备 16384，老设备 4096），而整张 1080×12000 的 RGBA 缓冲就有
/// 51.8 MB。所以按 [_kBandLogicalHeight] 一带一带地光栅化，逐带喂给 Rust 的
/// `FastPngWriter` 流式写进同一个 PNG —— 整张图的位图在任何一侧都不存在，
/// 峰值只跟带高有关（1080 宽的带 ≈ 8.6 MB），与篇幅无关。
abstract final class ImageComposer {
  /// 一带的逻辑高度。2000 × 3 倍 = 6000 物理像素，稳在所有设备的纹理上限之内。
  static const double _kBandLogicalHeight = 2000;

  /// 单带 RGBA 的字节上限之外，还挡一道离谱篇幅：超过这个逻辑高度就降档重来。
  static const double _kDowngradeAboveLogical = 60000;

  /// 预览的倍率上限。再高眼睛也看不出，白付内存。
  static const int _kMaxPreviewScale = 3;

  /// 预览所有带加起来的像素预算（RGBA 4 字节/像素，12M 像素 ≈ 48 MB）。
  static const int _kPreviewPixelBudget = 12 * 1000 * 1000;

  /// 出图并落盘。返回产物路径与像素尺寸。
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
      // 离谱篇幅（32 万字那篇外推约 50 万像素高）自动降档，仍然是一张，不弹询问。
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
            // 半张 PNG 不能留在盘上：相册里能打开，用户不会发现日记被截断了。
            await File(outPath).delete().catchError((_) => File(outPath));
            throw const ImageComposeCancelled();
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

  /// 预览用：同一棵树、同一套分带，只是把带交出去而不落盘。
  ///
  /// 调用方把这些带竖着摞起来就是整张长图（预览页正是这么做的），既避开了单张纹理上限，
  /// 也不必先落盘再解码。**用完必须逐个 `dispose`。**
  ///
  /// **倍率跟着屏幕走，不是固定 1**：卡片在预览页上按逻辑宽度铺开，3x 屏上一个逻辑像素
  /// 就是 3 个物理像素 —— 按 1 倍出图等于让 GPU 放大三倍，看着就是糊的。所以这里取
  /// [devicePixelRatio]，再被 [_kPreviewPixelBudget] 压一道：超长日记（每一带都要留在内存里）
  /// 宁可糊一点也不能吃掉几十 MB。
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
    // 布局与倍率无关，先按最大倍率建树、量出高度，再决定实际渲多细。
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

  /// 预览要把所有带同时留在内存里，所以按总像素数封顶：能按屏幕密度渲就渲，
  /// 渲不下就逐级降档（3 → 2 → 1），最差也比 OOM 强。
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

  /// 页脚的品牌标识：[MoodiaryLogo] 的预光栅化版本（离屏树不跑第二帧，SVG 必须先转位图）。
  /// 关了水印就不必解。
  static Future<ui.Image?> _brandMark(ImageCardStyle style, int scale) =>
      style.watermark
      ? MoodiaryLogo.rasterize(
          brightness: style.brightness,
          pixels: (kBrandMarkSize * scale).round(),
        )
      : Future.value();

  static List<(double, double)> _bands(int totalLogical) =>
      imageBands(totalLogical, _kBandLogicalHeight.toInt());

  /// 预解码正文里的图片与视频封面。
  ///
  /// **离屏渲染树不会跑第二帧**，`Image.file` 的异步 resolve 永远来不及，所以必须在进树
  /// 之前解成 `ui.Image`。解码时就按目标像素宽降采样（`targetWidth`），4000px 的原图不会
  /// 整张进堆。
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
        // 文件没了 / 解不动：走占位，不让整次导出失败。
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

/// 取消信号：产物已经清掉，调用方只需翻译成「已取消」。
class ImageComposeCancelled implements Exception {
  const ImageComposeCancelled();

  @override
  String toString() => 'ImageComposeCancelled';
}

/// 一棵挂在窗口之外的渲染树：布局一次，按带反复出图。
///
/// 四条硬约束（违反了就是空白图）：
///   1. 图片必须预解码好再进树（见 [ImageComposer._decodeImages]）；
///   2. `TextScaler.noScaling` —— 导出物的字号不跟手机的显示设置走；
///   3. 主题是快照（[ImageCardStyle]），树里没有祖先 `Theme`；
///   4. 每带出图后立刻 `dispose`。
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
          // 系统字号不进产物：文件的字号是定死的，不随手机的显示设置变。
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

  /// 出一带。只改偏移与带高，不重建 widget、不重排文字。
  ///
  /// [ratio] 缺省用建树时的倍率。布局是逻辑像素的、与倍率无关，所以同一棵已排好版的树
  /// 可以按任意倍率光栅化 —— 预览正是靠这一点先量高度、再决定渲多细。
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

/// 当前这一带的偏移与高度。用 [ChangeNotifier] 而不是重建 widget：
/// 树只建一次、只排一次版，换带只是换画。
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

/// 把一棵任意高的子树裁成「当前这一带」。
///
/// 子树按无限高布局一次（`contentHeight` 由此得到），之后换带只 `markNeedsPaint`：
/// 同一份约束下 `child.layout` 是空操作，文字不会重新排版。
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
    // 先铺底：最后一带的下沿可能超出内容高度（ceil 的余数），不能留下一条透明缝。
    context.canvas.drawRect(offset & size, Paint()..color = _background);
    context.pushClipRect(needsCompositing, offset, Offset.zero & size, (
      inner,
      innerOffset,
    ) {
      inner.paintChild(child!, innerOffset.translate(0, -_controller.offset));
    });
  }
}

/// 切带：`(offset, height)`，逻辑像素。
///
/// 三条性质是这套「分带出图、流式落盘」的地基，[imageBands] 的测试就是在钉它们：
///   1. **首尾相接、不重不漏**：各带高度之和恰好等于总高，拼起来就是原图；
///   2. **切点是整数**：乘上倍率不会出现半个像素，PNG 的行数才对得上声明的高度；
///   3. **至少一带**：空内容也要出一张 1px 高的图，而不是一个非法的 0 高 PNG。
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

/// [ImageComposer.renderBands] 的产物：竖着摞起来就是整张长图。
///
/// [logicalHeight] 是逻辑高度（与倍率无关），算产物尺寸角标要用它 —— 预览的倍率是
/// 按屏幕定的，跟用户在设置里选的导出倍率不是一回事。
class ImagePreviewBands {
  final List<ui.Image> bands;
  final double logicalHeight;

  /// 这批带实际用的光栅化倍率。
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
