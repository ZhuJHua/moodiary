import 'dart:io';

import 'package:dismissible_page/dismissible_page.dart';
import 'package:flutter/material.dart';
import 'package:moodiary/common/values/media_type.dart';
import 'package:moodiary/components/base/button.dart';
import 'package:moodiary/pages/image/image_logic.dart';
import 'package:moodiary/utils/media_util.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:refreshed/refreshed.dart';

Future<T?> showImageView<T>(
  BuildContext context,
  List<String> imagePathList,
  int initialIndex,
) async {
  return await context.pushTransparentRoute(
    ImagePage(imagePathList: imagePathList, initialIndex: initialIndex),
  );
}

class ImagePage extends StatelessWidget {
  final List<String> _imagePathList;
  final int _initialIndex;

  String get _tag => Object.hash(_imagePathList, _initialIndex).toString();

  const ImagePage({
    required List<String> imagePathList,
    required int initialIndex,
    super.key,
  }) : _imagePathList = imagePathList,
       _initialIndex = initialIndex;

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
    final gallery = PhotoViewGallery.builder(
      scrollPhysics: const PageScrollPhysics(),
      backgroundDecoration: const BoxDecoration(color: Colors.transparent),
      pageController: logic.pageController,
      enableRotation: false,
      scrollDirection: Axis.horizontal,
      wantKeepAlive: true,
      itemWrapper: (context, index, child) {
        return Obx(() {
          return HeroMode(
            enabled: index == state.imageIndex.value,
            child: child,
          );
        });
      },
      builder: (BuildContext context, int index) {
        return PhotoViewGalleryPageOptions(
          imageProvider: FileImage(File(state.imagePathList[index])),
          heroAttributes: PhotoViewHeroAttributes(
            tag: state.imagePathList[index],
          ),
          initialScale: PhotoViewComputedScale.contained,
          tightMode: true,
        );
      },
      itemCount: state.imagePathList.length,
      onPageChanged: logic.changePage,
    );
    return GetBuilder<ImageLogic>(
      tag: _tag,
      assignId: true,
      builder: (_) {
        return GestureDetector(
          onTap: () {
            Navigator.pop(context);
          },
          child: Stack(
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
                isFullScreen: true,
                minScale: 0.3,
                dragSensitivity: 1.0,
                child: gallery,
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
          ),
        );
      },
    );
  }
}
