import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:moodiary_models/moodiary_models.dart';

/// 由 `diary.content`（按 [Diary.type]）推导的派生视图：纯文本镜像 `contentText`、
/// 内嵌媒体文件名、双链目标。编辑保存（[EditController]）与数据修复
/// （[DiaryRepository.repairData]）共用，保证两条路径产出一致——修复重跑不会和保存结果
/// 打架（幂等）。
///
/// **一次解析、多项派生**：三项都是 `late final`，按需惰性计算并缓存，正文只在首次用到时
/// 解析一次（tiptap 走 [TiptapContent]、richText 走 [QuillDelta.ops]）。全库路径
/// （repairData / 迁移）同时要纯文本与媒体，旧的三个独立静态方法会把同一份正文解析 2–3 遍。
class DiaryContent {
  final Diary _diary;
  final DiaryType _type;

  DiaryContent._(this._diary, this._type);

  factory DiaryContent.of(Diary diary) =>
      DiaryContent._(diary, DiaryType.fromValue(diary.type));

  static final RegExp _markdownMedia = RegExp(
    r'!\[[^\]]*\]\((image-[^\s)]+|audio-[^\s)]+|video-[^\s)]+)\)',
  );

  /// tiptap 正文的解析句柄；其余类型为 null。
  late final TiptapContent? _tiptap = _type == DiaryType.tiptap
      ? TiptapContent.parse(_diary.content)
      : null;

  /// richText 正文的 Delta op 列表（非法 Delta 为 null）；其余类型为 null。
  late final List<dynamic>? _delta = _type == DiaryType.richText
      ? QuillDelta.ops(_diary.content)
      : null;

  /// 从 `content` 还原纯文本镜像。解析失败一律回退为原始 `content`，绝不抛出。
  late final String plainText = switch (_type) {
    DiaryType.tiptap => _tiptap!.plainText,
    DiaryType.markdown => MarkdownConverter.convert(_diary.content),
    DiaryType.richText =>
      QuillDelta.plainTextOf(_delta)?.trimRight() ?? _diary.content,
  };

  /// 抽取正文内嵌媒体文件名（去重、保持出现顺序）。Markdown 三类媒体统一写成
  /// `![](name)`，按文件名前缀（image-/audio-/video-）分类（与 TipTap 侧路由一致）。
  /// 解析失败回退到原字段，避免把已有引用误清空。
  late final ({List<String> images, List<String> videos, List<String> audios})
  media = _media();

  ({List<String> images, List<String> videos, List<String> audios}) _media() {
    switch (_type) {
      case DiaryType.tiptap:
        final m = _tiptap!.media;
        return (images: m.images, videos: m.videos, audios: m.audios);
      case DiaryType.markdown:
        final images = <String>{};
        final audios = <String>{};
        final videos = <String>{};
        for (final match in _markdownMedia.allMatches(_diary.content)) {
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
        final delta = _delta;
        if (delta == null) {
          return (
            images: _diary.imageName,
            videos: _diary.videoName,
            audios: _diary.audioName,
          );
        }
        final images = <String>{};
        final videos = <String>{};
        final audios = <String>{};
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
        return (
          images: images.toList(),
          videos: videos.toList(),
          audios: audios.toList(),
        );
    }
  }

  /// 抽取正文双链的目标日记 id（去重保序）。仅 tiptap 有 diaryLink 节点；其余类型返回空。
  late final List<String> links = switch (_type) {
    DiaryType.tiptap => _tiptap!.links,
    DiaryType.markdown || DiaryType.richText => const [],
  };
}
