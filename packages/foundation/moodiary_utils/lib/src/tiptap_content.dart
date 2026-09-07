import 'dart:convert';

import 'markdown_converter.dart';

class TiptapContent {
  final String _raw;
  final Map<String, dynamic>? _doc;

  TiptapContent._(this._raw, this._doc);

  factory TiptapContent.parse(String content) =>
      TiptapContent._(content, _tryDoc(content));

  bool get isDoc => _doc != null;

  static Map<String, dynamic>? _tryDoc(String content) {
    final trimmed = content.trimLeft();
    if (!trimmed.startsWith('{')) return null;
    try {
      final obj = jsonDecode(content);
      if (obj is Map<String, dynamic> && obj['type'] == 'doc') return obj;
    } catch (_) {
    }
    return null;
  }

  static const _blockTypes = {
    'paragraph',
    'heading',
    'listItem',
    'blockquote',
    'codeBlock',
    'horizontalRule',
  };

  static final RegExp _blankLines = RegExp(r'\n{3,}');

  static final RegExp _markdownMedia = RegExp(
    r'!\[[^\]]*\]\((image-[^\s)]+|audio-[^\s)]+|video-[^\s)]+)\)',
  );

  late final String plainText = _plainText();

  String _plainText() {
    final doc = _doc;
    if (doc == null) return MarkdownConverter.convert(_raw);
    final buf = StringBuffer();
    _collectText(doc, buf);
    return buf.toString().replaceAll(_blankLines, '\n\n').trim();
  }

  static void _collectText(dynamic node, StringBuffer buf) {
    if (node is! Map) return;
    final text = node['text'];
    if (text is String) buf.write(text);
    if (node['type'] == 'diaryLink') {
      final attrs = node['attrs'];
      if (attrs is Map && attrs['label'] is String) {
        buf.write(attrs['label'] as String);
      }
    }
    final content = node['content'];
    if (content is List) {
      for (final child in content) {
        _collectText(child, buf);
      }
    }
    if (_blockTypes.contains(node['type'])) buf.write('\n');
  }

  late final ({List<String> images, List<String> videos, List<String> audios})
  media = _media();

  ({List<String> images, List<String> videos, List<String> audios}) _media() {
    final images = <String>{};
    final audios = <String>{};
    final videos = <String>{};

    final doc = _doc;
    if (doc == null) {
      for (final m in _markdownMedia.allMatches(_raw)) {
        final name = m.group(1)!;
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
    }

    void walk(dynamic node) {
      if (node is! Map) return;
      final type = node['type'];
      final attrs = node['attrs'];
      if (attrs is Map) {
        if (type == 'image') {
          final s = attrs['src'];
          if (s is String && s.isNotEmpty && !_isExternalSrc(s)) images.add(s);
        } else if (type == 'audio') {
          final f = attrs['filename'];
          if (f is String && f.isNotEmpty) audios.add(f);
        } else if (type == 'video') {
          final f = attrs['filename'];
          if (f is String && f.isNotEmpty) videos.add(f);
        }
      }
      final content = node['content'];
      if (content is List) {
        for (final child in content) {
          walk(child);
        }
      }
    }

    walk(doc);
    return (
      images: images.toList(),
      videos: videos.toList(),
      audios: audios.toList(),
    );
  }

  late final List<String> links = _links();

  List<String> _links() {
    final doc = _doc;
    if (doc == null) return const [];
    final ids = <String>{};
    void walk(dynamic node) {
      if (node is! Map) return;
      if (node['type'] == 'diaryLink') {
        final attrs = node['attrs'];
        if (attrs is Map) {
          final id = attrs['id'];
          if (id is String && id.isNotEmpty) ids.add(id);
        }
      }
      final content = node['content'];
      if (content is List) {
        for (final child in content) {
          walk(child);
        }
      }
    }

    walk(doc);
    return ids.toList();
  }

  late final List<({int level, String text})> headings = _headings();

  List<({int level, String text})> _headings() {
    final doc = _doc;
    if (doc == null) return const [];
    final out = <({int level, String text})>[];
    void walk(dynamic node) {
      if (node is! Map) return;
      if (node['type'] == 'heading') {
        final attrs = node['attrs'];
        final raw = (attrs is Map) ? attrs['level'] : null;
        final level = (raw is int) ? (raw < 1 ? 1 : (raw > 6 ? 6 : raw)) : 1;
        final buf = StringBuffer();
        _collectInline(node['content'], buf);
        out.add((level: level, text: buf.toString().trim()));
      }
      final content = node['content'];
      if (content is List) {
        for (final child in content) {
          walk(child);
        }
      }
    }

    walk(doc);
    return out;
  }

  static bool _isExternalSrc(String src) =>
      src.startsWith('http://') ||
      src.startsWith('https://') ||
      src.startsWith('data:');

  static String wrapPlainText(String text) {
    final content = [
      for (final line in const LineSplitter().convert(text))
        {
          'type': 'paragraph',
          if (line.isNotEmpty)
            'content': [
              {'type': 'text', 'text': line},
            ],
        },
    ];
    if (content.isEmpty) content.add({'type': 'paragraph'});
    return jsonEncode({'type': 'doc', 'content': content});
  }

  static String ensureMedia(
    String docJson, {
    required List<String> images,
    required List<String> audios,
    required List<String> videos,
  }) {
    final parsed = TiptapContent.parse(docJson);
    final doc = parsed._doc;
    if (doc == null) return docJson;

    final present = parsed.media;
    final missing = <Map<String, dynamic>>[
      for (final name in {...images})
        if (name.isNotEmpty &&
            !_isExternalSrc(name) &&
            !present.images.contains(name))
          {
            'type': 'image',
            'attrs': {'src': name},
          },
      for (final name in {...audios})
        if (name.isNotEmpty && !present.audios.contains(name))
          {
            'type': 'audio',
            'attrs': {'filename': name},
          },
      for (final name in {...videos})
        if (name.isNotEmpty && !present.videos.contains(name))
          {
            'type': 'video',
            'attrs': {'filename': name},
          },
    ];
    if (missing.isEmpty) return docJson;

    final content = doc['content'];
    return jsonEncode({
      ...doc,
      'content': [...(content is List ? content : const []), ...missing],
    });
  }

  static void _collectInline(dynamic content, StringBuffer buf) {
    if (content is! List) return;
    for (final node in content) {
      if (node is! Map) continue;
      final text = node['text'];
      if (text is String) buf.write(text);
      if (node['type'] == 'diaryLink') {
        final attrs = node['attrs'];
        if (attrs is Map && attrs['label'] is String) {
          buf.write(attrs['label'] as String);
        }
      }
      _collectInline(node['content'], buf);
    }
  }
}
