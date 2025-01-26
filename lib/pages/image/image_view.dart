import 'dart:io';

import 'package:flutter/material.dart';
import 'package:moodiary/common/values/media_type.dart';
import 'package:moodiary/components/base/button.dart';
import 'package:moodiary/utils/media_util.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:refreshed/refreshed.dart';

import 'image_logic.dart';

class ImagePage extends StatelessWidget {
  const ImagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<ImageLogic>();
    final state = Bind.find<ImageLogic>().state;
    final colorScheme = Theme.of(context).colorScheme;
    return GetBuilder<ImageLogic>(
      builder: (_) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: colorScheme.scrim.withAlpha((255 * 0.6).toInt()),
            title: Obx(() {
              return Visibility(
                visible: state.imagePathList.length > 1,
                child: Text(
                  '${state.imageIndex.value + 1}/${state.imagePathList.length}',
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                  onPressed: () {
                    MediaUtil.saveToGallery(
                        path: state.imagePathList[state.imageIndex.value],
                        type: MediaType.image);
                  },
                  icon: const Icon(Icons.save_alt)),
            ],
          ),
          body: Stack(
            alignment: Alignment.center,
            children: [
              PhotoViewGallery.builder(
                scrollPhysics: const PageScrollPhysics(),
                pageController: logic.pageController,
                builder: (BuildContext context, int index) {
                  return PhotoViewGalleryPageOptions(
                    imageProvider: FileImage(File(state.imagePathList[index])),
                    heroAttributes: PhotoViewHeroAttributes(
                      tag: state.imagePathList[index],
                    ),
                  );
                },
                itemCount: state.imagePathList.length,
                onPageChanged: logic.changePage,
                loadingBuilder: (context, event) =>
                    const Center(child: CircularProgressIndicator()),
              ),
              Obx(() {
                return Visibility(
                  visible: state.imageIndex.value != 0,
                  child: Positioned(
                    left: 16,
                    child: FrostedGlassButton(
                      size: 40,
                      onPressed: logic.previous,
                      child: const Icon(
                        Icons.chevron_left_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              }),
              Obx(() {
                return Visibility(
                  visible:
                      state.imageIndex.value != state.imagePathList.length - 1,
                  child: Positioned(
                    right: 16,
                    child: FrostedGlassButton(
                      size: 40,
                      onPressed: logic.next,
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
