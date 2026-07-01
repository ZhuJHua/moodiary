import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_core/moodiary_core.dart';

/// Quill BlockEmbed：图片。Delta JSON 形式 `{"insert":{"image":"image-xxx.jpg"}}`。
/// 落库的 [name] 仅为文件名（已落在 [FileUtil.getRealPath]\('image'\) 目录），
/// 编辑 / 浏览都直接按真实路径读，不再区分 isEdit。
class ImageBlockEmbed extends BlockEmbed {
  const ImageBlockEmbed(String value) : super(embedType, value);

  static const String embedType = 'image';

  static ImageBlockEmbed fromName(String name) => ImageBlockEmbed(name);

  String get name => data as String;
}

class ImageEmbedBuilder extends EmbedBuilder {
  ImageEmbedBuilder();

  @override
  String get key => ImageBlockEmbed.embedType;

  @override
  String toPlainText(Embed node) => '';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final name = embedContext.node.value.data as String;
    final path = FileUtil.getRealPath('image', name);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300),
        child: MoodiaryImage(
          imagePath: path,
          size: 300,
          heroTag: '$name-quill',
          borderRadius: AppBorderRadius.mediumBorderRadius,
          showBorder: true,
          padding: const EdgeInsets.all(8.0),
        ),
      ),
    );
  }
}
