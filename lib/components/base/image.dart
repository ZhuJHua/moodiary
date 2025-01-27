import 'dart:io';

import 'package:flutter/material.dart';
import 'package:moodiary/utils/media_util.dart';

class ThumbnailImage extends StatelessWidget {
  final String imagePath;
  final int size;
  final BoxFit? fit;
  final Function() onTap;

  const ThumbnailImage({
    super.key,
    required this.imagePath,
    required this.size,
    this.fit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fileImage = FileImage(File(imagePath));
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final colorScheme = Theme.of(context).colorScheme;
    final Future getAspectRatio = MediaUtil.getImageAspectRatio(fileImage);
    return FutureBuilder(
      future: getAspectRatio,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          final aspectRatio = snapshot.data as double;
          return GestureDetector(
            onTap: onTap,
            child: Hero(
              tag: imagePath,
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: ResizeImage(
                      fileImage,
                      width: aspectRatio < 1.0
                          ? size * devicePixelRatio.toInt()
                          : null,
                      height: aspectRatio >= 1.0
                          ? (size * devicePixelRatio).toInt()
                          : null,
                    ),
                    fit: fit ?? BoxFit.cover,
                  ),
                ),
              ),
            ),
          );
        } else {
          return Container(
            color: colorScheme.surfaceContainer,
            child: const Center(
              child: Icon(
                Icons.image_search_rounded,
              ),
            ),
          );
        }
      },
    );
  }
}
