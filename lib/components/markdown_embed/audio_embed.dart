import 'package:flutter/widgets.dart';
import 'package:moodiary/utils/file_util.dart';

import '../audio_player/audio_player_view.dart';

class MarkdownAudioEmbed extends StatelessWidget {
  final String audioName;
  final bool isEdit;

  const MarkdownAudioEmbed({
    super.key,
    required this.audioName,
    required this.isEdit,
  });

  @override
  Widget build(BuildContext context) {
    final path =
        isEdit
            ? FileUtil.getCachePath(audioName)
            : FileUtil.getRealPath('audio', audioName);

    return AudioPlayerComponent(path: path); // 使用音频播放器组件渲染
  }
}
