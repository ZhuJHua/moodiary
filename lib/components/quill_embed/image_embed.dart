import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:moodiary/common/values/border.dart';
import 'package:moodiary/components/base/image.dart';
import 'package:moodiary/pages/image/image_view.dart';
import 'package:moodiary/utils/file_util.dart';

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
  Widget build(BuildContext context, EmbedContext embedContext) {
    final imageEmbed = ImageBlockEmbed(embedContext.node.value.data);
    // 从数据构造 ImageBlockEmbed
    final imagePath =
        isEdit
            ? imageEmbed.name
            : FileUtil.getRealPath('image', imageEmbed.name);
    final image = MoodiaryImage(
      imagePath: imagePath,
      size: 300,
      heroTag: '${imageEmbed.name}0',
      borderRadius: AppBorderRadius.mediumBorderRadius,
      showBorder: true,
      padding: const EdgeInsets.all(8.0),
      onTap: () {
        if (!isEdit) {
          showImageView(
            context,
            [imagePath],
            0,
            heroTagPrefix: imageEmbed.name,
          );
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
