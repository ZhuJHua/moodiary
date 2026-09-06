import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:photo_view/photo_view.dart';

import 'derivatives.dart';
import 'rust/api/image.dart';
import 'tile_view.dart';

class FastTileSource {
  final Size size;

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

class FastTileImageViewer extends StatefulWidget {
  final String path;

  final String? decodePath;

  final Size imageSize;

  final ImageProvider overview;

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
