import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:mood_diary/components/video_player/video_player_view.dart';
import 'package:mood_diary/utils/utils.dart';

class VideoBlockEmbed extends BlockEmbed {
  const VideoBlockEmbed(String value) : super(embedType, value);

  static const String embedType = 'video';

  static VideoBlockEmbed fromName(String name) => VideoBlockEmbed(name);

  String get name => data as String;
}

class VideoEmbedBuilder extends EmbedBuilder {
  final bool isEdit;

  VideoEmbedBuilder({required this.isEdit});

  @override
  String get key => VideoBlockEmbed.embedType;

  @override
  String toPlainText(Embed node) => '';

  @override
  Widget build(
    BuildContext context,
    EmbedContext embedContext,
  ) {
    final videoEmbed = VideoBlockEmbed(embedContext.node.value.data);
    final videoPath = isEdit ? videoEmbed.name : Utils().fileUtil.getRealPath('video', videoEmbed.name);

    return Card.filled(
      clipBehavior: Clip.hardEdge,
      child: VideoPlayerComponent(
        videoPath: videoPath,
      ),
    ); // 使用音频播放器组件渲染
  }
}
