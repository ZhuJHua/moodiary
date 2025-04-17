import 'package:flutter/material.dart';
import 'package:moodiary/common/values/border.dart';
import 'package:moodiary/components/base/image.dart';
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
    final image = MoodiaryImage(
      imagePath: imagePath,
      size: 300,
      heroTag: '${heroPrefix}0',
      borderRadius: AppBorderRadius.mediumBorderRadius,
      showBorder: true,
      padding: const EdgeInsets.all(8.0),
      onTap: () {
        if (!isEdit) {
          showImageView(context, [imagePath], 0, heroTagPrefix: heroPrefix);
        }
      },
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300),
        child: image,
      ),
    );
  }
}
