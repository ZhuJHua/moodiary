import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_core/moodiary_core.dart';

/// Quill BlockEmbed：音频。Delta JSON `{"insert":{"audio":"audio-xxx.m4a"}}`。
/// 路径解析与 image/video 一致，全部走 [FileUtil.getRealPath]\('audio'\)。
class AudioBlockEmbed extends BlockEmbed {
  const AudioBlockEmbed(String value) : super(embedType, value);

  static const String embedType = 'audio';

  static AudioBlockEmbed fromName(String name) => AudioBlockEmbed(name);

  String get name => data as String;
}

class AudioEmbedBuilder extends EmbedBuilder {
  AudioEmbedBuilder();

  @override
  String get key => AudioBlockEmbed.embedType;

  @override
  String toPlainText(Embed node) => '';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final name = embedContext.node.value.data as String;
    final path = FileUtil.getRealPath('audio', name);
    return AudioPlayerComponent(path: path);
  }
}
