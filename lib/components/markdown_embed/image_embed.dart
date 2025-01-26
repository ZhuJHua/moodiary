import 'dart:io';

import 'package:flutter/material.dart';
import 'package:moodiary/router/app_routes.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:refreshed/refreshed.dart';

class MarkdownImageEmbed extends StatelessWidget {
  final bool isEdit;
  final String imageName;

  const MarkdownImageEmbed(
      {super.key, required this.isEdit, required this.imageName});

  @override
  Widget build(
    BuildContext context,
  ) {
    final imagePath =
        isEdit ? imageName : FileUtil.getRealPath('image', imageName);

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
          child: Hero(
            tag: imagePath,
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
