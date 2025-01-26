import 'package:flutter/material.dart';
import 'package:moodiary/components/video_player/video_player_view.dart';
import 'package:moodiary/utils/file_util.dart';

class MarkdownVideoEmbed extends StatelessWidget {
  final bool isEdit;
  final String videoName;

  const MarkdownVideoEmbed(
      {super.key, required this.isEdit, required this.videoName});

  @override
  Widget build(
    BuildContext context,
  ) {
    final videoPath =
        isEdit ? videoName : FileUtil.getRealPath('video', videoName);
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300),
        child: Card.outlined(
          clipBehavior: Clip.hardEdge,
          color: colorScheme.surfaceContainerLowest,
          child: VideoPlayerComponent(
            videoPath: videoPath,
          ),
        ),
      ),
    ); // 使用音频播放器组件渲染
  }
}
