import 'dart:io';

import 'package:flutter/material.dart';
import 'package:moodiary/utils/media_util.dart';

class ThumbnailImage extends StatelessWidget {
  final String imagePath;
  final int size;
  final BoxFit? fit;
  final Function() onTap;

  final String heroTag;

  const ThumbnailImage({
    super.key,
    required this.imagePath,
    required this.size,
    this.fit,
    required this.onTap,
    required this.heroTag,
  });

  Widget _buildImage({
    required double aspectRatio,
    required ImageProvider imageProvider,
    required double pixelRatio,
  }) {
    final image = Image(
      key: ValueKey(imagePath),
      image: ResizeImage(
        imageProvider,
        width: aspectRatio < 1.0 ? size * pixelRatio.toInt() : null,
        height: aspectRatio >= 1.0 ? (size * pixelRatio).toInt() : null,
      ),
      fit: fit ?? BoxFit.cover,
    );
    return GestureDetector(
      onTap: onTap,
      child: Hero(tag: heroTag, child: image),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileImage = FileImage(File(imagePath));
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final colorScheme = Theme.of(context).colorScheme;
    final Future getAspectRatio = MediaUtil.getImageAspectRatio(fileImage);
    final loading = ColoredBox(
      color: colorScheme.surfaceContainer,
      child: const Center(child: Icon(Icons.image_search_rounded)),
    );
    return FutureBuilder(
      future: getAspectRatio,
      builder: (context, snapshot) {
        return switch (snapshot.connectionState) {
          ConnectionState.none => loading,
          ConnectionState.waiting => loading,
          ConnectionState.active => loading,
          ConnectionState.done => _buildImage(
            aspectRatio: snapshot.data as double,
            imageProvider: fileImage,
            pixelRatio: devicePixelRatio,
          ),
        };
      },
    );
  }
}
