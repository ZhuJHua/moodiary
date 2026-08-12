import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

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
  late final _loadState = ValueNotifier(_ImageLoadState.loading);

  late _ImageState _imageState;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _loadState.dispose();
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
    _loadState.value = .loading;
    try {
      final imageAspect = ImageSizeManager().getAspectRatio(widget.imagePath);

      final imageSize = widget.size;
      final width = imageAspect < 1.0
          ? imageSize
          : (imageSize * imageAspect).ceil();
      final height = imageAspect >= 1.0
          ? imageSize
          : (imageSize / imageAspect).ceil();

      final path = await ImageCacheStore().getLocalImagePathWithCache(
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

      _loadState.value = .success;
    } catch (e) {
      _loadState.value = .error;
    }
  }

  BorderRadius _shrinkBorderRadius(BorderRadius radius, double amount) {
    return .only(
      topLeft: .elliptical(
        (radius.topLeft.x - amount).clamp(0, double.infinity),
        (radius.topLeft.y - amount).clamp(0, double.infinity),
      ),
      topRight: .elliptical(
        (radius.topRight.x - amount).clamp(0, double.infinity),
        (radius.topRight.y - amount).clamp(0, double.infinity),
      ),
      bottomLeft: .elliptical(
        (radius.bottomLeft.x - amount).clamp(0, double.infinity),
        (radius.bottomLeft.y - amount).clamp(0, double.infinity),
      ),
      bottomRight: .elliptical(
        (radius.bottomRight.x - amount).clamp(0, double.infinity),
        (radius.bottomRight.y - amount).clamp(0, double.infinity),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const borderWidth = 1.0;

    final outerRadius = widget.borderRadius ?? .zero;
    final innerRadius = widget.showBorder
        ? _shrinkBorderRadius(outerRadius, borderWidth)
        : outerRadius;

    return Container(
      decoration: BoxDecoration(
        borderRadius: outerRadius,
        border: widget.showBorder
            ? .all(
                color: context.theme.colors.outline.withValues(alpha: 0.6),
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
          child: ValueListenableBuilder(
            valueListenable: _loadState,
            builder: (context, loadState, child) {
              switch (loadState) {
                case .loading:
                  return const _LoadingPlaceholder(key: ValueKey('loading'));
                case .error:
                  return const _ErrorPlaceholder(key: ValueKey('error'));
                case .success:
                  final imagePath = _imageState.path;
                  final width = _imageState.width;
                  final height = _imageState.height;
                  return GestureDetector(
                    key: const ValueKey('image'),
                    onTap: widget.onTap != null
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
                    behavior: .translucent,
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
                          fit: widget.fit ?? .cover,
                          width: width.toDouble(),
                          height: height.toDouble(),
                          imageErrorBuilder: (_, _, _) {
                            return const _ErrorPlaceholder(
                              key: ValueKey('image_error'),
                            );
                          },
                        ),
                      ),
                    ),
                  );
              }
            },
          ),
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
      color: context.theme.colors.errorContainer,
      child: Center(
        child: Icon(
          LucideIcons.circleAlert,
          color: context.theme.colors.onErrorContainer,
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
      color: context.theme.colors.surfaceContainer,
      child: Center(
        child: Icon(
          LucideIcons.image,
          color: context.theme.colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
