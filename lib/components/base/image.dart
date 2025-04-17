import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/utils/cache_util.dart';
import 'package:moodiary/utils/log_util.dart';

final kTransparentImage = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

enum _ImageLoadState { loading, error, success }

class _ImageState {
  final int width;
  final int height;
  final String path;
  final double aspectRatio;

  _ImageState({
    required this.width,
    required this.height,
    required this.path,
    required this.aspectRatio,
  });
}

class MoodiaryImage extends StatefulWidget {
  final String imagePath;
  final int size;
  final BoxFit? fit;
  final VoidCallback? onTap;
  final String? heroTag;
  final BorderRadius? borderRadius;
  final bool showBorder;
  final EdgeInsets? padding;

  const MoodiaryImage({
    super.key,
    required this.imagePath,
    required this.size,
    this.fit,
    this.onTap,
    this.heroTag,
    this.borderRadius,
    this.showBorder = false,
    this.padding,
  });

  @override
  State<MoodiaryImage> createState() => _MoodiaryImageState();
}

class _MoodiaryImageState extends State<MoodiaryImage> {
  final Rx<_ImageLoadState> _loadState = Rx<_ImageLoadState>(
    _ImageLoadState.loading,
  );

  late _ImageState _imageState;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _loadState.close();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MoodiaryImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imagePath != oldWidget.imagePath ||
        widget.size != oldWidget.size) {
      _loadImage();
    }
  }

  void _loadImage() async {
    _loadState.value = _ImageLoadState.loading;
    try {
      logger.d('Image loaded from path: ${widget.imagePath}');
      final imageAspect = await ImageCacheUtil().getImageAspectRatioWithCache(
        imagePath: widget.imagePath,
      );

      final imageSize = widget.size;
      final width =
          imageAspect < 1.0 ? imageSize : (imageSize * imageAspect).ceil();
      final height =
          imageAspect >= 1.0 ? imageSize : (imageSize / imageAspect).ceil();

      final path = await ImageCacheUtil().getLocalImagePathWithCache(
        imagePath: widget.imagePath,
        imageWidth: width * 2,
        imageHeight: height * 2,
        imageAspectRatio: imageAspect,
      );

      _imageState = _ImageState(
        width: width,
        height: height,
        path: path,
        aspectRatio: imageAspect,
      );

      _loadState.value = _ImageLoadState.success;
    } catch (e) {
      _loadState.value = _ImageLoadState.error;
    }
  }

  BorderRadius _shrinkBorderRadius(BorderRadius radius, double amount) {
    return BorderRadius.only(
      topLeft: Radius.elliptical(
        (radius.topLeft.x - amount).clamp(0, double.infinity),
        (radius.topLeft.y - amount).clamp(0, double.infinity),
      ),
      topRight: Radius.elliptical(
        (radius.topRight.x - amount).clamp(0, double.infinity),
        (radius.topRight.y - amount).clamp(0, double.infinity),
      ),
      bottomLeft: Radius.elliptical(
        (radius.bottomLeft.x - amount).clamp(0, double.infinity),
        (radius.bottomLeft.y - amount).clamp(0, double.infinity),
      ),
      bottomRight: Radius.elliptical(
        (radius.bottomRight.x - amount).clamp(0, double.infinity),
        (radius.bottomRight.y - amount).clamp(0, double.infinity),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const borderWidth = 1.0;

    final outerRadius = widget.borderRadius ?? BorderRadius.zero;
    final innerRadius =
        widget.showBorder
            ? _shrinkBorderRadius(outerRadius, borderWidth)
            : outerRadius;

    return Container(
      decoration: BoxDecoration(
        borderRadius: outerRadius,
        border:
            widget.showBorder
                ? Border.all(
                  color: context.theme.colorScheme.outline.withValues(
                    alpha: 0.6,
                  ),
                  width: borderWidth,
                )
                : null,
      ),
      margin: widget.padding,
      child: ClipRRect(
        borderRadius: innerRadius,
        child: AnimatedSwitcher(
          duration: Durations.short3,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: Obx(() {
            switch (_loadState.value) {
              case _ImageLoadState.loading:
                return const _LoadingPlaceholder(key: ValueKey('loading'));
              case _ImageLoadState.error:
                return const _ErrorPlaceholder(key: ValueKey('error'));
              case _ImageLoadState.success:
                final imagePath = _imageState.path;
                final width = _imageState.width;
                final height = _imageState.height;

                return GestureDetector(
                  key: const ValueKey('image'),
                  onTap:
                      widget.onTap != null
                          ? () async {
                            if (widget.heroTag != null) {
                              await precacheImage(
                                FileImage(File(widget.imagePath)),
                                context,
                              );
                            }
                            widget.onTap?.call();
                          }
                          : null,
                  behavior: HitTestBehavior.translucent,
                  child: HeroMode(
                    enabled: widget.heroTag != null,
                    child: Hero(
                      tag: widget.heroTag ?? '',
                      child: FadeInImage(
                        key: ValueKey(imagePath),
                        image: FileImage(File(imagePath)),
                        placeholder: MemoryImage(kTransparentImage),
                        fadeInDuration: Durations.short2,
                        fadeOutDuration: Durations.short1,
                        fit: widget.fit ?? BoxFit.cover,
                        width: width.toDouble(),
                        height: height.toDouble(),
                        imageErrorBuilder: (_, __, ___) {
                          return const _ErrorPlaceholder(
                            key: ValueKey('image_error'),
                          );
                        },
                      ),
                    ),
                  ),
                );
            }
          }),
        ),
      ),
    );
  }
}

class _ErrorPlaceholder extends StatelessWidget {
  const _ErrorPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.theme.colorScheme.errorContainer,
      child: Center(
        child: Icon(
          Icons.error_rounded,
          color: context.theme.colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.theme.colorScheme.surfaceContainer,
      child: Center(
        child: Icon(
          Icons.image_search_rounded,
          color: context.theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
