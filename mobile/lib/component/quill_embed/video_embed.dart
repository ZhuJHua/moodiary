import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_ui/moodiary_ui.dart';

/// Quill BlockEmbed：视频。Delta JSON `{"insert":{"video":"video-xxx.mp4"}}`。
/// 文件名指向 [FileUtil.getRealPath]\('video'\) 下的真实文件，附带缩略图。
class VideoBlockEmbed extends BlockEmbed {
  const VideoBlockEmbed(String value) : super(embedType, value);

  static const String embedType = 'video';

  static VideoBlockEmbed fromName(String name) => VideoBlockEmbed(name);

  String get name => data as String;
}

class VideoEmbedBuilder extends EmbedBuilder {
  /// 编辑态下 [VideoPlayerComponent] 跳过封面图叠层，渲染原生 chewie；
  /// 详情态会先盖一层缩略图，再播放器加载后淡出。
  final bool isEdit;

  VideoEmbedBuilder({this.isEdit = false});

  @override
  String get key => VideoBlockEmbed.embedType;

  @override
  String toPlainText(Embed node) => '';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final name = embedContext.node.value.data as String;
    final path = FileUtil.getRealPath('video', name);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300),
        child: Card.outlined(
          clipBehavior: Clip.hardEdge,
          color: context.theme.colorScheme.surfaceContainerLowest,
          child: VideoPlayerComponent(videoPath: path, isEdit: isEdit),
        ),
      ),
    );
  }
}
