import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:photo_view/photo_view.dart';

import 'derivatives.dart';
import 'rust/api/image.dart';
import 'tile_view.dart';

/// 一张图能不能走分片：能的话给（转正后尺寸, 交给 Rust 解的文件）。
///
/// baseline JPEG、非隔行 PNG、非动图 WebP 直接解原件；大的 progressive JPEG 解它的 baseline
/// 副本（不在就现转，见 [FastImageDerivatives.ensureBaseline]）；其余给 null，调用方走整图。
class FastTileSource {
  final Size size;

  /// 交给 [FastRegionDecoder] 打开的文件。
  final String decodePath;

  const FastTileSource({required this.size, required this.decodePath});

  static Future<FastTileSource?> resolve(String path) async {
    final probe = await FastImageCodec.probe(filePath: path);
    final size = Size(probe.width.toDouble(), probe.height.toDouble());
    if (probe.regionDecodable) {
      return FastTileSource(size: size, decodePath: path);
    }
    if (probe.format == FastImageFormat.jpeg && probe.progressive) {
      final baseline = await FastImageDerivatives.ensureBaseline(path);
      if (baseline != null) {
        return FastTileSource(size: size, decodePath: baseline);
      }
    }
    return null;
  }
}

/// 分片看图页：自己持有 [PhotoViewController]（[FastTileImageView] 靠它算可见区域），
/// 生命周期跟页元素一致 —— PageView 会销毁两页外的页，复用的控制器会带着上次的平移量回来。
///
/// 放大上限跟分辨率走，不跟屏幕比例走：铺满屏再放 3 倍，或者放到每个源像素占 2 个物理像素
/// （1:1 再放一倍，系统相册的口径），取大者。
class FastTileImageViewer extends StatefulWidget {
  /// 原图绝对路径（打底与兜底用）。
  final String path;

  /// 交给 Rust 区域解码的文件；默认就是 [path]。
  final String? decodePath;

  /// 转正后的源图尺寸。
  final Size imageSize;

  /// 打底用的缩略图。
  final ImageProvider overview;

  /// 是不是当前页：只有当前页开解码器、解 tile。
  final bool active;

  final ValueChanged<PhotoViewScaleState>? onScaleState;
  final VoidCallback? onTap;

  const FastTileImageViewer({
    super.key,
    required this.path,
    this.decodePath,
    required this.imageSize,
    required this.overview,
    this.active = true,
    this.onScaleState,
    this.onTap,
  });

  @override
  State<FastTileImageViewer> createState() => _FastTileImageViewerState();
}

class _FastTileImageViewerState extends State<FastTileImageViewer> {
  final _controller = PhotoViewController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.imageSize;
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final covered = math.max(
          constraints.maxWidth / size.width,
          constraints.maxHeight / size.height,
        );
        return PhotoView.customChild(
          childSize: size,
          controller: _controller,
          backgroundDecoration: const BoxDecoration(color: Color(0x00000000)),
          initialScale: PhotoViewComputedScale.contained,
          minScale: PhotoViewComputedScale.contained,
          maxScale: math.max(covered * 3, 2 / dpr),
          scaleStateChangedCallback: widget.onScaleState,
          onTapUp: widget.onTap == null ? null : (_, _, _) => widget.onTap!(),
          child: FastTileImageView(
            path: widget.path,
            decodePath: widget.decodePath,
            imageSize: size,
            controller: _controller,
            viewportSize: constraints.biggest,
            overview: widget.overview,
            active: widget.active,
          ),
        );
      },
    );
  }
}
