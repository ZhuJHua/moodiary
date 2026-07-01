import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:moodiary_models/moodiary_models.dart';

/// 由 `diary.content`（按 [Diary.type]）推导纯文本镜像 `contentText` 与内嵌媒体文件名。
/// 编辑保存（[EditController]）与数据修复（[DiaryRepository.repairData]）共用，保证两条
/// 路径产出一致——修复重跑不会和保存结果打架（幂等）。
class DiaryContentUtil {
  const DiaryContentUtil._();

  static final RegExp _markdownMedia = RegExp(
    r'!\[[^\]]*\]\((image-[^\s)]+|audio-[^\s)]+|video-[^\s)]+)\)',
  );

  /// 从 `content` 还原纯文本镜像。解析失败一律回退为原始 `content`，绝不抛出。
  static String derivePlainText(Diary diary) {
    switch (DiaryType.fromValue(diary.type)) {
      case DiaryType.tiptap:
        return TiptapContent.plainText(diary.content);
      case DiaryType.markdown:
        return MarkdownConverter.convert(diary.content);
      case DiaryType.richText:
        try {
          final delta = jsonDecode(diary.content);
          if (delta is! List) return diary.content;
          return Document.fromJson(delta).toPlainText().trimRight();
        } catch (_) {
          return diary.content;
        }
    }
  }

  /// 抽取正文内嵌媒体文件名（去重、保持出现顺序）。Markdown 三类媒体统一写成
  /// `![](name)`，按文件名前缀（image-/audio-/video-）分类（与 TipTap 侧路由一致）。
  /// 解析失败回退到原字段，避免把已有引用误清空。
  static ({List<String> images, List<String> videos, List<String> audios})
  extractMedia(Diary diary) {
    switch (DiaryType.fromValue(diary.type)) {
      case DiaryType.tiptap:
        final m = TiptapContent.media(diary.content);
        return (images: m.images, videos: m.videos, audios: m.audios);
      case DiaryType.markdown:
        final images = <String>{};
        final audios = <String>{};
        final videos = <String>{};
        for (final match in _markdownMedia.allMatches(diary.content)) {
          final name = match.group(1)!;
          if (name.startsWith('video-')) {
            videos.add(name);
          } else if (name.startsWith('audio-')) {
            audios.add(name);
          } else {
            images.add(name);
          }
        }
        return (
          images: images.toList(),
          videos: videos.toList(),
          audios: audios.toList(),
        );
      case DiaryType.richText:
        final images = <String>{};
        final videos = <String>{};
        final audios = <String>{};
        try {
          final delta = jsonDecode(diary.content);
          if (delta is! List) {
            return (
              images: diary.imageName,
              videos: diary.videoName,
              audios: diary.audioName,
            );
          }
          for (final op in delta) {
            if (op is! Map) continue;
            final insert = op['insert'];
            if (insert is! Map) continue;
            final img = insert['image'];
            if (img is String) images.add(img);
            final vid = insert['video'];
            if (vid is String) videos.add(vid);
            final aud = insert['audio'];
            if (aud is String) audios.add(aud);
          }
        } catch (_) {
          return (
            images: diary.imageName,
            videos: diary.videoName,
            audios: diary.audioName,
          );
        }
        return (
          images: images.toList(),
          videos: videos.toList(),
          audios: audios.toList(),
        );
    }
  }

  /// 抽取正文双链的目标日记 id（去重保序）。仅 tiptap 有 diaryLink 节点；其余类型返回空。
  static List<String> extractLinks(Diary diary) {
    switch (DiaryType.fromValue(diary.type)) {
      case DiaryType.tiptap:
        return TiptapContent.links(diary.content);
      case DiaryType.markdown:
      case DiaryType.richText:
        return const [];
    }
  }
}
