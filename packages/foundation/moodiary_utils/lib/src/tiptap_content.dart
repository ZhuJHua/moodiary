import 'dart:convert';

import 'markdown_converter.dart';

/// 解析一次的 TipTap 文档句柄：纯文本镜像、内嵌媒体、双链目标、大纲四项派生共用同一棵
/// 已解析的树（落库 content=JSON 的 [DiaryType.tiptap] 日记用）。
///
/// 各派生都是 `late final`，按需惰性计算并缓存——只取一项时开销与旧的一次性静态调用相同，
/// 取多项时省掉重复的 `jsonDecode`（重索引 / 数据修复这类全库路径上这是主要成本）。
///
/// 识别不出 JSON 文档时退化为「旧 markdown 模式」，各派生走各自的回退（MarkdownConverter /
/// `![](name)` 正则 / 空），故对旧 markdown 内容同样安全。
class TiptapContent {
  final String _raw;
  final Map<String, dynamic>? _doc;

  TiptapContent._(this._raw, this._doc);

  factory TiptapContent.parse(String content) =>
      TiptapContent._(content, _tryDoc(content));

  /// 是否解析出了 TipTap 文档（false = 旧 markdown / richText 内容，走回退路径）。
  bool get isDoc => _doc != null;

  /// 解析为 TipTap 文档（`{"type":"doc",...}`）；非 JSON 文档返回 null。
  static Map<String, dynamic>? _tryDoc(String content) {
    final trimmed = content.trimLeft();
    if (!trimmed.startsWith('{')) return null;
    try {
      final obj = jsonDecode(content);
      if (obj is Map<String, dynamic> && obj['type'] == 'doc') return obj;
    } catch (_) {
      /* 非 JSON，回退 */
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

  /// 纯文本镜像（搜索分词 / 卡片预览 / 字数）。
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
    // 双链 chip：把链接标签计入纯文本（搜索 / 卡片预览 / 字数）。
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
    // 块级节点后补换行，避免相邻段落文字粘连。
    if (_blockTypes.contains(node['type'])) buf.write('\n');
  }

  /// 内嵌媒体文件名（去重、保持出现顺序）。JSON 按节点 type 分类；旧 markdown 回退正则按前缀分类。
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
          if (s is String && s.isNotEmpty) images.add(s);
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

  /// 内嵌双链的目标日记 id（diaryLink 节点 attrs.id；去重保序）。非 tiptap JSON 返回空
  /// （旧 markdown / richText 无双链节点）。供反向链接索引用。
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

  /// 文档大纲：按出现顺序的 heading 节点（级别 1-6 + 标题纯文本）。非 tiptap JSON 返回空
  /// （旧 markdown / richText 不解析）。供目录（TOC）用；顺序与编辑器侧 heading 顺序一致，
  /// 故列表下标即 `scrollToHeading(index)` 的 index。
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

  /// 收集一个块内的内联文本（不补块级换行，供标题文本用）。
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
