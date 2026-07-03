import 'dart:io';

import 'package:flutter/material.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

/// 媒体库图片全屏画廊：左右滑动浏览 [names]、双指缩放，由 [show] 全屏弹出。
class MediaImageViewer extends StatefulWidget {
  final List<String> names;
  final int initialIndex;

  const MediaImageViewer({
    super.key,
    required this.names,
    required this.initialIndex,
  });

  static Future<void> show(
    BuildContext context, {
    required List<String> names,
    required int initialIndex,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, _, _) =>
            MediaImageViewer(names: names, initialIndex: initialIndex),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<MediaImageViewer> createState() => _MediaImageViewerState();
}

class _MediaImageViewerState extends State<MediaImageViewer> {
  late final PageController _pageController =
      PageController(initialPage: widget.initialIndex);
  late int _current = widget.initialIndex;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            itemCount: widget.names.length,
            pageController: _pageController,
            onPageChanged: (i) => setState(() => _current = i),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            loadingBuilder: (_, _) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            builder: (context, index) {
              final path = FileUtil.getRealPath('image', widget.names[index]);
              return PhotoViewGalleryPageOptions(
                imageProvider: FileImage(File(path)),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3,
              );
            },
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black38,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          if (widget.names.length > 1)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 16,
              right: 16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Text(
                    '${_current + 1} / ${widget.names.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
