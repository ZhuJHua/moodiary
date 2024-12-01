import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:mood_diary/utils/utils.dart';

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
    final imagePath = isEdit ? imageEmbed.name : Utils().fileUtil.getRealPath('image', imageEmbed.name);

    return Card.filled(
      clipBehavior: Clip.hardEdge,
      child: Image.file(File(imagePath)),
    );
  }
}
