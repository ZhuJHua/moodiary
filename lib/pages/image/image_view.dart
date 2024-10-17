import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import 'image_logic.dart';

class ImagePage extends StatelessWidget {
  const ImagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<ImageLogic>();
    final state = Bind.find<ImageLogic>().state;
    final colorScheme = Theme.of(context).colorScheme;
    return GetBuilder<ImageLogic>(
      assignId: true,
      init: logic,
      builder: (logic) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: colorScheme.scrim.withAlpha((255 * 0.6).toInt()),
            title: Text(
              '${state.imageIndex + 1}/${state.imagePathList.length}',
              style: const TextStyle(color: Colors.white),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: PhotoViewGallery.builder(
            scrollPhysics: const PageScrollPhysics(),
            pageController: state.pageController,
            builder: (BuildContext context, int index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: FileImage(File(state.imagePathList[index])),
                heroAttributes: PhotoViewHeroAttributes(tag: index),
              );
            },
            itemCount: state.imagePathList.length,
            onPageChanged: (index) {
              logic.changePage(index);
            },
            loadingBuilder: (context, event) => Center(
              child: SizedBox(
                width: 20.0,
                height: 20.0,
                child: CircularProgressIndicator(
                  value: event == null ? 0 : (event.cumulativeBytesLoaded / event.expectedTotalBytes!),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
