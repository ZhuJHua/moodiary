import 'dart:convert';

import 'package:characters/characters.dart';

import 'markdown_converter.dart';
import 'media_markup.dart';

typedef ContentMedia = ({
  List<String> images,
  List<String> videos,
  List<String> audios,
  List<String> files,
});

class TiptapContent {
  static const int _schemaVersion = 2;

  static const List<int> _widthPercentStops = [25, 50, 75, 100];

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
    } catch (_) {}
    return null;
  }

  late final Map<String, dynamic>? _v2 = switch (_doc) {
    final doc? => normalizeDoc(doc),
    null => null,
  };

  static String normalize(String content) {
    final c = TiptapContent.parse(content);
    return c._doc == null || identical(c._v2, c._doc)
        ? content
        : jsonEncode(c._v2);
  }

  static Map<String, dynamic> normalizeDoc(Map<String, dynamic> doc) {
    final attrs = doc['attrs'];
    final v = attrs is Map ? attrs['v'] : null;
    if (v is int && v > _schemaVersion) return doc;

    Map<String, dynamic>? out;
    if (v != _schemaVersion) {
      out = {
        ...doc,
        'attrs': {if (attrs is Map) ...attrs, 'v': _schemaVersion},
      };
    }
    final content = doc['content'];
    if (content is List) {
      final next = _normalizeList(content);
      if (!identical(next, content)) (out ??= {...doc})['content'] = next;
    }
    return out ?? doc;
  }

  static List<dynamic> _normalizeList(List<dynamic> nodes) {
    List<dynamic>? out;
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (node is! Map) continue;
      final next = _normalizeNode(node);
      if (!identical(next, node)) (out ??= List.of(nodes))[i] = next;
    }
    return out ?? nodes;
  }

  static Map<dynamic, dynamic> _normalizeNode(Map<dynamic, dynamic> node) {
    Map<String, dynamic>? out;
    Map<String, dynamic> edit() => out ??= Map<String, dynamic>.from(node);

    final attrs = node['attrs'];
    final nextAttrs = _normalizeAttrs(node['type'], attrs);
    if (!identical(nextAttrs, attrs)) edit()['attrs'] = nextAttrs;

    final marks = node['marks'];
    if (marks is List) {
      final nextMarks = _normalizeMarks(marks);
      if (!identical(nextMarks, marks)) edit()['marks'] = nextMarks;
    }

    final content = node['content'];
    if (content is List) {
      final nextContent = _normalizeList(content);
      if (!identical(nextContent, content)) edit()['content'] = nextContent;
    }
    return out ?? node;
  }

  static Object? _normalizeAttrs(Object? type, Object? attrs) {
    switch (type) {
      case 'audio' || 'video':
        if (attrs is! Map || !attrs.containsKey('filename')) return attrs;
        final src = attrs['src'];
        return {
          for (final e in attrs.entries)
            if (e.key != 'filename') e.key: e.value,
          'src': src is String && src.isNotEmpty ? src : attrs['filename'],
        };
      case 'image':
        if (attrs is! Map) return attrs;
        final width = attrs['widthPercent'];
        final snapped = width == null ? null : _snapWidthPercent(width);
        if (!attrs.keys.any(_droppedImageAttrs.contains) && snapped == width) {
          return attrs;
        }
        final name =
            attrs['name'] ??
            _nonEmpty(attrs['alt']) ??
            _nonEmpty(attrs['title']);
        return {
          for (final e in attrs.entries)
            if (!_droppedImageAttrs.contains(e.key)) e.key: e.value,
          if (attrs.containsKey('widthPercent')) 'widthPercent': snapped,
          'name': ?name,
        };
      case 'diaryLink':
        if (attrs is! Map || !attrs.containsKey('mentionSuggestionChar')) {
          return attrs;
        }
        return {
          for (final e in attrs.entries)
            if (e.key != 'mentionSuggestionChar') e.key: e.value,
        };
      case 'horizontalRule':
        if (attrs is! Map) return {'variant': 'solid', 'label': null};
        if (attrs['variant'] is String && attrs.containsKey('label')) {
          return attrs;
        }
        return {
          ...attrs,
          if (attrs['variant'] is! String) 'variant': 'solid',
          if (!attrs.containsKey('label')) 'label': null,
        };
      default:
        return attrs;
    }
  }

  static List<dynamic> _normalizeMarks(List<dynamic> marks) {
    List<dynamic>? out;
    for (var i = 0; i < marks.length; i++) {
      final mark = marks[i];
      if (mark is! Map || mark['type'] != 'link') continue;
      final attrs = mark['attrs'];
      if (attrs is! Map || attrs.keys.every((k) => k == 'href')) continue;
      (out ??= List.of(marks))[i] = {
        ...Map<String, dynamic>.from(mark),
        'attrs': {'href': attrs['href']},
      };
    }
    return out ?? marks;
  }

  static const _droppedImageAttrs = {'width', 'height', 'alt', 'title'};

  static String? _nonEmpty(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static int? _snapWidthPercent(Object? value) {
    if (value is! num || !value.isFinite) return null;
    final clamped = value.round().clamp(25, 100);
    var best = _widthPercentStops.first;
    for (final stop in _widthPercentStops) {
      if ((clamped - stop).abs() <= (clamped - best).abs()) best = stop;
    }
    return best;
  }

  static const _textblocks = {'paragraph', 'heading', 'codeBlock'};

  static const _mediaKinds = {
    'image': MediaKind.image,
    'video': MediaKind.video,
    'audio': MediaKind.audio,
    'attachment': MediaKind.attachment,
  };

  // 与 ProseMirror textBetween(0, size, '\n') 逐字一致
  late final String plainText = _plainText();

  String _plainText() {
    final doc = _v2;
    if (doc == null) return MediaMarkup.strip(MarkdownConverter.convert(_raw));
    final buf = StringBuffer();
    var first = true;
    void separate() {
      if (first) {
        first = false;
      } else {
        buf.write('\n');
      }
    }

    void walk(Object? node) {
      if (node is! Map) return;
      final type = node['type'];
      switch (type) {
        case 'text':
          final text = node['text'];
          if (text is String) buf.write(MediaMarkup.strip(text));
        case 'hardBreak':
          buf.write('\n');
        case 'diaryLink':
          buf.write(MediaMarkup.strip(_diaryLinkText(node['attrs'])));
        case 'horizontalRule':
          return;
        default:
          if (_mediaKinds[type] case final kind?) {
            final name = _mediaName(node['attrs']);
            if (name.isEmpty) return;
            separate();
            buf.write(MediaMarkup.mark(kind, name));
            return;
          }
          final content = node['content'];
          if (_textblocks.contains(type) || _hasTextChild(content)) separate();
          if (content is List) content.forEach(walk);
      }
    }

    final content = doc['content'];
    if (content is List) content.forEach(walk);
    return buf.toString();
  }

  static bool _hasTextChild(Object? content) =>
      content is List && content.any((c) => c is Map && c['type'] == 'text');

  static String _mediaName(Object? attrs) {
    if (attrs is! Map) return '';
    final name = attrs['name'];
    return name is String ? MediaMarkup.sanitizeName(name) : '';
  }

  static String _diaryLinkText(Object? attrs) {
    if (attrs is! Map) return '';
    final label = attrs['label'];
    if (label is String && label.isNotEmpty) return label;
    final id = attrs['id'];
    return id is String ? id : '';
  }

  static final RegExp _whitespace = RegExp(r'\s+');

  static int countCharacters(String text) =>
      MediaMarkup.body(text).replaceAll(_whitespace, '').characters.length;

  static final RegExp _markdownMedia = RegExp(
    r'!\[[^\]]*\]\((image-[^\s)]+|audio-[^\s)]+|video-[^\s)]+)\)',
  );

  late final ContentMedia media = _media();

  ContentMedia _media() {
    final images = <String>{};
    final audios = <String>{};
    final videos = <String>{};
    final files = <String>{};

    final doc = _v2;
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
    } else {
      void walk(Object? node) {
        if (node is! Map) return;
        final into = switch (node['type']) {
          'image' => images,
          'audio' => audios,
          'video' => videos,
          'attachment' => files,
          _ => null,
        };
        final attrs = node['attrs'];
        if (into != null && attrs is Map) {
          final src = attrs['src'];
          if (src is String && src.isNotEmpty && !_isExternalSrc(src)) {
            into.add(src);
          }
        }
        final content = node['content'];
        if (content is List) content.forEach(walk);
      }

      walk(doc);
    }
    return (
      images: images.toList(),
      videos: videos.toList(),
      audios: audios.toList(),
      files: files.toList(),
    );
  }

  bool get isLegacy {
    final attrs = _doc?['attrs'];
    final v = attrs is Map ? attrs['v'] : null;
    return _doc != null && (v is! int || v < _schemaVersion);
  }

  late final Map<String, String> mediaNames = _mediaNames();

  Map<String, String> _mediaNames() {
    final doc = _v2;
    if (doc == null) return const {};
    final out = <String, String>{};
    void walk(Object? node) {
      if (node is! Map) return;
      final attrs = node['attrs'];
      if (_mediaKinds.containsKey(node['type']) && attrs is Map) {
        final src = attrs['src'];
        final name = _mediaName(attrs);
        if (src is String && name.isNotEmpty) out.putIfAbsent(src, () => name);
      }
      final content = node['content'];
      if (content is List) content.forEach(walk);
    }

    walk(doc);
    return out;
  }

  // 返回原串即未改；v1 的音视频 src 还在 filename 里
  static String mapMediaNames(
    String content,
    String? Function(String type, String src, String? name) rename,
  ) {
    final doc = _tryDoc(content);
    if (doc == null) return content;
    var changed = false;
    void walk(Object? node) {
      if (node is! Map) return;
      final type = node['type'];
      final attrs = node['attrs'];
      if (type is String && _mediaKinds.containsKey(type) && attrs is Map) {
        final src = _nonEmpty(attrs['src']) ?? _nonEmpty(attrs['filename']);
        final name = attrs['name'];
        if (src != null) {
          final next = rename(type, src, name is String ? name : null);
          if (next != name) {
            attrs['name'] = next;
            changed = true;
          }
        }
      }
      final content = node['content'];
      if (content is List) content.forEach(walk);
    }

    walk(doc);
    return changed ? jsonEncode(doc) : content;
  }

  late final List<String> links = _links();

  List<String> _links() {
    final doc = _v2;
    if (doc == null) return const [];
    final ids = <String>{};
    void walk(Object? node) {
      if (node is! Map) return;
      if (node['type'] == 'diaryLink') {
        final attrs = node['attrs'];
        if (attrs is Map) {
          final id = attrs['id'];
          if (id is String && id.isNotEmpty) ids.add(id);
        }
      }
      final content = node['content'];
      if (content is List) content.forEach(walk);
    }

    walk(doc);
    return ids.toList();
  }

  late final List<({int level, String text})> headings = _headings();

  List<({int level, String text})> _headings() {
    final doc = _v2;
    if (doc == null) return const [];
    final out = <({int level, String text})>[];
    void walk(Object? node) {
      if (node is! Map) return;
      if (node['type'] == 'heading') {
        final attrs = node['attrs'];
        final raw = (attrs is Map) ? attrs['level'] : null;
        final level = (raw is int) ? raw.clamp(1, 6) : 1;
        final buf = StringBuffer();
        _collectInline(node['content'], buf);
        out.add((level: level, text: buf.toString().trim()));
      }
      final content = node['content'];
      if (content is List) content.forEach(walk);
    }

    walk(doc);
    return out;
  }

  static bool _isExternalSrc(String src) =>
      src.startsWith('http://') ||
      src.startsWith('https://') ||
      src.startsWith('data:') ||
      src.startsWith('file:') ||
      src.contains('/');

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
    return jsonEncode(newDoc(content));
  }

  static Map<String, dynamic> newDoc(List<Map<String, dynamic>> content) => {
    'type': 'doc',
    'attrs': {'v': _schemaVersion},
    'content': content,
  };

  static Map<String, dynamic> attachmentNode({
    required String src,
    String? name,
    String? mime,
    int? size,
  }) => {
    'type': 'attachment',
    'attrs': {'src': src, 'name': name, 'mime': mime, 'size': size},
  };

  static String ensureMedia(
    String docJson, {
    required List<String> images,
    required List<String> audios,
    required List<String> videos,
    List<String> files = const [],
  }) {
    final parsed = TiptapContent.parse(docJson);
    final doc = parsed._v2;
    if (doc == null) return docJson;

    final present = parsed.media;
    Iterable<String> missing(List<String> names, List<String> have) => {
      ...names,
    }.where((n) => n.isNotEmpty && !_isExternalSrc(n) && !have.contains(n));

    final added = <Map<String, dynamic>>[
      for (final name in missing(images, present.images))
        {
          'type': 'image',
          'attrs': {'src': name},
        },
      for (final name in missing(audios, present.audios))
        {
          'type': 'audio',
          'attrs': {'src': name},
        },
      for (final name in missing(videos, present.videos))
        {
          'type': 'video',
          'attrs': {'src': name},
        },
      for (final name in missing(files, present.files))
        attachmentNode(src: name),
    ];
    if (added.isEmpty) return docJson;

    final content = doc['content'];
    return jsonEncode({
      ...doc,
      'content': [...(content is List ? content : const []), ...added],
    });
  }

  static void _collectInline(Object? content, StringBuffer buf) {
    if (content is! List) return;
    for (final node in content) {
      if (node is! Map) continue;
      final text = node['text'];
      if (text is String) buf.write(text);
      if (node['type'] == 'diaryLink') buf.write(_diaryLinkText(node['attrs']));
      _collectInline(node['content'], buf);
    }
  }
}
