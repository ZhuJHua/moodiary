import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:mood_diary/router/app_routes.dart';
import 'package:refreshed/refreshed.dart';

import '../../utils/file_util.dart';

class ImageBlockEmbed extends BlockEmbed {
  const ImageBlockEmbed(String value) : super(embedType, value);

  static const String embedType = 'image';

  static ImageBlockEmbed fromName(String name) => ImageBlockEmbed(name);

  String get name => data as String;
}

class ImageEmbedBuilder extends EmbedBuilder {
  final bool isEdit;

  ImageEmbedBuilder({required this.isEdit});

  @override
  String get key => ImageBlockEmbed.embedType;

  @override
  String toPlainText(Embed node) => '';

  @override
  Widget build(
    BuildContext context,
    EmbedContext embedContext,
  ) {
    final imageEmbed = ImageBlockEmbed(embedContext.node.value.data);
    // 从数据构造 ImageBlockEmbed
    final imagePath = isEdit
        ? imageEmbed.name
        : FileUtil.getRealPath('image', imageEmbed.name);

    return Center(
      child: GestureDetector(
        onTap: () {
          if (!isEdit) {
            Get.toNamed(AppRoutes.photoPage, arguments: [
              [imagePath],
              0,
            ]);
          }
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: Card.outlined(
            clipBehavior: Clip.hardEdge,
            color: Colors.transparent,
            child: Image.file(File(imagePath)),
          ),
        ),
      ),
    );
  }
}
