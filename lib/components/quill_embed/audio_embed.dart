import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../utils/file_util.dart';
import '../audio_player/audio_player_view.dart';

class AudioBlockEmbed extends BlockEmbed {
  const AudioBlockEmbed(String value) : super(embedType, value);

  static const String embedType = 'audio';

  static AudioBlockEmbed fromName(String name) => AudioBlockEmbed(name);

  String get name => data as String;
}

class AudioEmbedBuilder extends EmbedBuilder {
  final bool isEdit;

  AudioEmbedBuilder({required this.isEdit});

  @override
  String get key => AudioBlockEmbed.embedType;

  @override
  String toPlainText(Embed node) => '';

  @override
  Widget build(
    BuildContext context,
    EmbedContext embedContext,
  ) {
    final audioEmbed = AudioBlockEmbed(embedContext.node.value.data); // 从数据构造 AudioBlockEmbed
    final path = isEdit ? FileUtil.getCachePath(audioEmbed.name) : FileUtil.getRealPath('audio', audioEmbed.name);

    return AudioPlayerComponent(path: path); // 使用音频播放器组件渲染
  }
}
