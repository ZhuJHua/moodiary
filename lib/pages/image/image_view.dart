import 'dart:io';

import 'package:dismissible_page/dismissible_page.dart';
import 'package:flutter/material.dart';
import 'package:moodiary/common/values/media_type.dart';
import 'package:moodiary/components/base/button.dart';
import 'package:moodiary/pages/image/image_logic.dart';
import 'package:moodiary/utils/media_util.dart';
import 'package:photo_view/photo_view.dart';
import 'package:refreshed/refreshed.dart';

Future<T?> showImageView<T>(
  BuildContext context,
  List<String> imagePathList,
  int initialIndex, {
  required String heroTagPrefix,
}) async {
  return await context.pushTransparentRoute(
    ImagePage(
      imagePathList: imagePathList,
      initialIndex: initialIndex,
      heroTagPrefix: heroTagPrefix,
    ),
  );
}

class ImagePage extends StatelessWidget {
  final List<String> _imagePathList;
  final int _initialIndex;

  final String _heroTagPrefix;

  String get _tag => Object.hash(_imagePathList, _initialIndex).toString();

  const ImagePage({
    required List<String> imagePathList,
    required int initialIndex,
    required String heroTagPrefix,
    super.key,
  }) : _imagePathList = imagePathList,
       _initialIndex = initialIndex,
       _heroTagPrefix = heroTagPrefix;

  Widget _buildOperationButton({
    required Function() onSaved,
    required Function() onExit,
    required RxInt imageIndex,
    required List<String> imagePathList,
    required TextStyle? textStyle,
    required RxDouble opacity,
  }) {
    return Obx(() {
      return Opacity(
        opacity: opacity.value,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: onExit,
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
            Obx(() {
              return Text(
                '${imageIndex.value + 1}/${imagePathList.length}',
                style: textStyle?.copyWith(color: Colors.white),
              );
            }),
            IconButton(
              onPressed: onSaved,
              icon: const Icon(Icons.save_alt, color: Colors.white),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildPageButton({
    required Function() previous,
    required Function() next,
    required RxDouble opacity,
    required RxInt imageIndex,
    required List<String> imagePathList,
  }) {
    return Obx(() {
      return Opacity(
        opacity: opacity.value,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Obx(() {
              return Visibility(
                visible: imageIndex.value != 0,
                child: FrostedGlassButton(
                  size: 40,
                  onPressed: previous,
                  child: const Icon(
                    Icons.chevron_left_rounded,
                    color: Colors.white,
                  ),
                ),
              );
            }),
            Obx(() {
              return Visibility(
                visible: imageIndex.value != imagePathList.length - 1,
                child: FrostedGlassButton(
                  size: 40,
                  onPressed: next,
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                  ),
                ),
              );
            }),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(
      ImageLogic(imagePathList: _imagePathList, initialIndex: _initialIndex),
      tag: _tag,
    );
    final state = Bind.find<ImageLogic>(tag: _tag).state;
    final textStyle = Theme.of(context).textTheme;
    final imageView = ImageViewGallery(
      imagePathList: state.imagePathList,
      initialIndex: state.imageIndex.value,
      pageController: logic.pageController,
      heroTagPrefix: _heroTagPrefix,
    );
    return GetBuilder<ImageLogic>(
      tag: _tag,
      assignId: true,
      builder: (_) {
        return Stack(
          alignment: Alignment.center,
          children: [
            DismissiblePage(
              backgroundColor: Colors.black,
              onDismissed: () {
                Navigator.pop(context);
              },
              onDragUpdate: (details) {
                logic.updateOpacity(details.opacity);
              },
              direction: DismissiblePageDismissDirection.vertical,
              minScale: 0.2,
              dragSensitivity: 0.8,
              startingOpacity: 0.9,
              maxTransformValue: 0.6,
              child: imageView,
            ),
            Positioned(
              left: 24,
              right: 24,
              child: _buildPageButton(
                previous: logic.previous,
                next: logic.next,
                opacity: state.opacity,
                imageIndex: state.imageIndex,
                imagePathList: state.imagePathList,
              ),
            ),
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: SafeArea(
                top: false,
                child: _buildOperationButton(
                  onSaved: () {
                    MediaUtil.saveToGallery(
                      path: state.imagePathList[state.imageIndex.value],
                      type: MediaType.image,
                    );
                  },
                  onExit: () {
                    Navigator.pop(context);
                  },
                  imageIndex: state.imageIndex,
                  imagePathList: state.imagePathList,
                  textStyle: textStyle.labelLarge,
                  opacity: state.opacity,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class ImageViewGallery extends StatefulWidget {
  final List<String> imagePathList;
  final int initialIndex;

  final String _heroTagPrefix;

  final PageController pageController;

  const ImageViewGallery({
    required this.imagePathList,
    required this.initialIndex,
    required this.pageController,
    required String heroTagPrefix,
    super.key,
  }) : _heroTagPrefix = heroTagPrefix;

  @override
  State<ImageViewGallery> createState() => _ImageViewGalleryState();
}

class _ImageViewGalleryState extends State<ImageViewGallery> {
  late int currentIndex;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    currentIndex = widget.initialIndex;
    widget.pageController.addListener(() {
      final index = widget.pageController.page?.round() ?? 0;
      if (currentIndex != index) {
        setState(() {
          currentIndex = index;
        });
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imagePathList.length == 1) {
      return PhotoView(
        imageProvider: FileImage(File(widget.imagePathList[0])),
        backgroundDecoration: const BoxDecoration(color: Colors.transparent),
        initialScale: PhotoViewComputedScale.contained,
        minScale: PhotoViewComputedScale.contained,
        onTapDown: (context, details, controllerValue) {
          Navigator.pop(context);
        },
        heroAttributes: PhotoViewHeroAttributes(
          tag: '${widget._heroTagPrefix}0',
        ),
      );
    }
    return PageView.builder(
      itemBuilder: (context, index) {
        return HeroMode(
          enabled: index == currentIndex,
          child: PhotoView(
            imageProvider: FileImage(File(widget.imagePathList[index])),
            heroAttributes: PhotoViewHeroAttributes(
              tag: '${widget._heroTagPrefix}$index',
            ),
            onTapDown: (context, details, controllerValue) {
              Navigator.pop(context);
            },
            backgroundDecoration: const BoxDecoration(
              color: Colors.transparent,
            ),
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained,
          ),
        );
      },
      controller: widget.pageController,
      itemCount: widget.imagePathList.length,
    );
  }
}
