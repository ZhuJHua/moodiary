import 'dart:io';

import 'package:flutter/material.dart';
import 'package:moodiary/pages/image/image_view.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:uuid/uuid.dart';

class MarkdownImageEmbed extends StatelessWidget {
  final bool isEdit;
  final String imageName;

  const MarkdownImageEmbed({
    super.key,
    required this.isEdit,
    required this.imageName,
  });

  @override
  Widget build(BuildContext context) {
    final imagePath =
        isEdit ? imageName : FileUtil.getRealPath('image', imageName);
    final heroPrefix = const Uuid().v4();
    return Center(
      child: GestureDetector(
        onTap: () {
          if (!isEdit) {
            showImageView(context, [imagePath], 0, heroTagPrefix: heroPrefix);
          }
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: Hero(
            tag: '${heroPrefix}0',
            child: Card.outlined(
              clipBehavior: Clip.hardEdge,
              color: Colors.transparent,
              child: Image.file(File(imagePath)),
            ),
          ),
        ),
      ),
    );
  }
}
