import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

class DiaryContent {
  final Diary _diary;
  final DiaryType _type;

  DiaryContent._(this._diary, this._type);

  factory DiaryContent.of(Diary diary) =>
      DiaryContent._(diary, .fromValue(diary.type));

  static final RegExp _markdownMedia = RegExp(
    r'!\[[^\]]*\]\((image-[^\s)]+|audio-[^\s)]+|video-[^\s)]+)\)',
  );

  late final TiptapContent? _tiptap = _type == .tiptap
      ? .parse(_diary.content)
      : null;

  late final List<dynamic>? _delta = _type == .richText
      ? QuillDelta.ops(_diary.content)
      : null;

  late final String plainText = switch (_type) {
    .tiptap => _tiptap!.plainText,
    .markdown => MarkdownConverter.convert(_diary.content),
    .richText => QuillDelta.plainTextOf(_delta)?.trimRight() ?? _diary.content,
  };

  late final ({List<String> images, List<String> videos, List<String> audios})
  media = _media();

  ({List<String> images, List<String> videos, List<String> audios}) _media() =>
      _salvage(_parseMedia());

  ({List<String> images, List<String> videos, List<String> audios}) _salvage(
    ({List<String> images, List<String> videos, List<String> audios}) parsed,
  ) {
    List<String> keep(List<String> derived, List<String> existing) {
      final seen = derived.toSet();
      final rescued = existing.where(
        (ref) => !seen.contains(ref) && _diary.content.contains(ref),
      );
      return rescued.isEmpty ? derived : [...derived, ...rescued];
    }

    return (
      images: keep(parsed.images, _diary.imageName),
      videos: keep(parsed.videos, _diary.videoName),
      audios: keep(parsed.audios, _diary.audioName),
    );
  }

  ({List<String> images, List<String> videos, List<String> audios})
  _parseMedia() {
    switch (_type) {
      case .tiptap:
        final m = _tiptap!.media;
        return (images: m.images, videos: m.videos, audios: m.audios);
      case .markdown:
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
      case .richText:
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

  late final List<String> links = switch (_type) {
    .tiptap => _tiptap!.links,
    .markdown || .richText => const [],
  };
}
