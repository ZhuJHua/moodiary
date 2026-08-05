import 'dart:convert';

import 'export_doc.dart';

/// 媒体裸文件名 → 绝对路径。`kind` 取 `image` / `audio` / `video` / `thumbnail`，
/// 与 core 的 `AppFiles.getRealPath` 同签名 —— 本包是 foundation 叶子，不能反向依赖 core，
/// 故由调用方注入。
typedef ResolveMediaPath = String Function(String kind, String name);

/// tiptap 文档 JSON → [ExportDoc]。
///
/// 与 [MarkdownToTiptap] 互为反向，但**不是无损往返**：markdown 表达不了 diaryLink、
/// image 的 widthPercent、表格的合并与对齐，这些在 markdown writer 里会降级（docx/pdf 保留）。
///
/// 认不出的节点类型记进 [ExportDoc.unsupportedNodes] 而不是抛异常 —— 一篇日记里的一个
/// 怪节点不该让整批 300 篇的导出失败；但也不静默，UI 负责把它报出来。
class TiptapToExportDoc {
  const TiptapToExportDoc._();

  static const _mediaPrefixes = {'image-', 'audio-', 'video-'};

  static ExportDoc convert({
    required String id,
    required String title,
    required DateTime time,
    required String content,
    required ResolveMediaPath resolvePath,
    double mood = 0.5,
    List<String> weather = const [],
    List<String> position = const [],
    List<String> tags = const [],
    String? categoryName,
  }) {
    final unsupported = <String>{};
    final blocks = <ExportBlock>[];

    final doc = _tryDoc(content);
    if (doc != null) {
      _blocks(doc['content'], blocks, unsupported, resolvePath);
    } else if (content.trim().isNotEmpty) {
      // 旧 markdown / richText 日记：不在这里解析，交由调用方先经 MarkdownToTiptap
      // 转换。走到这里说明调用方没转，按整段纯文本降级，至少不丢字。
      blocks.add(ParagraphBlock([ExportSpan(content)]));
    }

    return ExportDoc(
      id: id,
      title: title,
      time: time,
      mood: mood,
      weather: weather,
      position: position,
      tags: tags,
      categoryName: categoryName,
      blocks: blocks,
      unsupportedNodes: unsupported,
    );
  }

  static Map<String, dynamic>? _tryDoc(String content) {
    final trimmed = content.trimLeft();
    if (!trimmed.startsWith('{')) return null;
    try {
      final obj = jsonDecode(content);
      if (obj is Map<String, dynamic> && obj['type'] == 'doc') return obj;
    } catch (_) {
      /* 非 JSON */
    }
    return null;
  }

  static void _blocks(
    dynamic content,
    List<ExportBlock> out,
    Set<String> unsupported,
    ResolveMediaPath resolve,
  ) {
    if (content is! List) return;
    for (final node in content) {
      if (node is! Map) continue;
      _block(node, out, unsupported, resolve);
    }
  }

  static void _block(
    Map node,
    List<ExportBlock> out,
    Set<String> unsupported,
    ResolveMediaPath resolve,
  ) {
    final attrs = node['attrs'];
    switch (node['type']) {
      case 'paragraph':
        final spans = _inline(node['content'], unsupported);
        // 空段落保留：它在原文里是有意的留白，markdown/docx 都靠它分段。
        out.add(ParagraphBlock(spans));

      case 'heading':
        final raw = (attrs is Map) ? attrs['level'] : null;
        final level = (raw is int) ? raw.clamp(1, 6) : 1;
        out.add(HeadingBlock(level, _inline(node['content'], unsupported)));

      case 'blockquote':
        final children = <ExportBlock>[];
        _blocks(node['content'], children, unsupported, resolve);
        out.add(QuoteBlock(children));

      case 'bulletList':
        out.add(
          ListBlock(
            ordered: false,
            items: _items(node['content'], unsupported, resolve),
          ),
        );

      case 'orderedList':
        final rawStart = (attrs is Map) ? attrs['start'] : null;
        out.add(
          ListBlock(
            ordered: true,
            start: rawStart is int ? rawStart : 1,
            items: _items(node['content'], unsupported, resolve),
          ),
        );

      case 'taskList':
        out.add(
          ListBlock(
            ordered: false,
            items: _items(node['content'], unsupported, resolve),
          ),
        );

      case 'codeBlock':
        final lang = (attrs is Map) ? attrs['language'] : null;
        out.add(
          CodeBlock(
            _plainText(node['content']),
            language: lang is String && lang.isNotEmpty ? lang : null,
          ),
        );

      case 'horizontalRule':
        out.add(const DividerBlock());

      case 'image':
        final block = _image(attrs, resolve);
        if (block != null) out.add(block);

      case 'audio':
      case 'video':
        final block = _media(node['type'] as String, attrs, resolve);
        if (block != null) out.add(block);

      case 'table':
        out.add(_table(node['content'], unsupported, resolve));

      default:
        final type = node['type'];
        if (type is String) unsupported.add(type);
    }
  }

  static List<ExportListItem> _items(
    dynamic content,
    Set<String> unsupported,
    ResolveMediaPath resolve,
  ) {
    if (content is! List) return const [];
    final items = <ExportListItem>[];
    for (final node in content) {
      if (node is! Map) continue;
      final type = node['type'];
      if (type != 'listItem' && type != 'taskItem') {
        if (type is String) unsupported.add(type);
        continue;
      }
      final children = <ExportBlock>[];
      _blocks(node['content'], children, unsupported, resolve);
      final attrs = node['attrs'];
      final checked = (type == 'taskItem')
          ? ((attrs is Map && attrs['checked'] == true))
          : null;
      items.add(ExportListItem(children, checked: checked));
    }
    return items;
  }

  static TableBlock _table(
    dynamic content,
    Set<String> unsupported,
    ResolveMediaPath resolve,
  ) {
    final rows = <List<ExportCell>>[];
    if (content is! List) return TableBlock(rows);
    for (final row in content) {
      if (row is! Map || row['type'] != 'tableRow') continue;
      final cells = <ExportCell>[];
      final rowContent = row['content'];
      if (rowContent is List) {
        for (final cell in rowContent) {
          if (cell is! Map) continue;
          final isHeader = cell['type'] == 'tableHeader';
          if (!isHeader && cell['type'] != 'tableCell') continue;
          final attrs = cell['attrs'];
          final children = <ExportBlock>[];
          _blocks(cell['content'], children, unsupported, resolve);
          final align = (attrs is Map) ? attrs['align'] : null;
          cells.add(
            ExportCell(
              children,
              header: isHeader,
              colspan: _span(attrs, 'colspan'),
              rowspan: _span(attrs, 'rowspan'),
              align: align is String && align.isNotEmpty ? align : null,
            ),
          );
        }
      }
      rows.add(cells);
    }
    return TableBlock(rows);
  }

  /// 合并跨度：属性缺失或非法（0 / 负数）时退回 1。
  static int _span(dynamic attrs, String key) {
    if (attrs is! Map) return 1;
    final v = attrs[key];
    return (v is int && v >= 1) ? v : 1;
  }

  static ImageBlock? _image(dynamic attrs, ResolveMediaPath resolve) {
    if (attrs is! Map) return null;
    final src = attrs['src'];
    if (src is! String || src.isEmpty) return null;

    final alt = attrs['alt'];
    final wp = attrs['widthPercent'];

    if (_isExternal(src)) {
      return ImageBlock(
        path: src,
        alt: alt is String ? alt : null,
        widthPercent: wp is int ? wp : null,
        isExternal: true,
      );
    }
    return ImageBlock(
      path: resolve('image', src),
      alt: alt is String ? alt : null,
      widthPercent: wp is int ? wp : null,
    );
  }

  static MediaBlock? _media(
    String type,
    dynamic attrs,
    ResolveMediaPath resolve,
  ) {
    if (attrs is! Map) return null;
    final name = attrs['filename'];
    if (name is! String || name.isEmpty) return null;
    final isVideo = type == 'video';
    return MediaBlock(
      kind: isVideo ? ExportMediaKind.video : ExportMediaKind.audio,
      filename: name,
      path: resolve(type, name),
      coverPath: isVideo ? resolve('thumbnail', name) : null,
    );
  }

  /// 外链媒体：编辑器允许粘贴 http(s) 图片，此时 src 不是 `image-` 裸名。
  /// 拿它当本地名去拼路径会得到一个必然不存在的文件。
  static bool _isExternal(String src) {
    if (_mediaPrefixes.any(src.startsWith)) return false;
    return src.startsWith('http://') || src.startsWith('https://');
  }

  /// 收集行内节点为 span 列表，相邻同样式片段合并。
  static List<ExportSpan> _inline(dynamic content, Set<String> unsupported) {
    final spans = <ExportSpan>[];
    if (content is! List) return spans;

    void push(ExportSpan span) {
      if (span.text.isEmpty) return;
      final last = spans.isEmpty ? null : spans.last;
      if (last != null && _sameStyle(last, span)) {
        spans[spans.length - 1] = ExportSpan(
          last.text + span.text,
          bold: last.bold,
          italic: last.italic,
          strike: last.strike,
          underline: last.underline,
          code: last.code,
          href: last.href,
          diaryLinkId: last.diaryLinkId,
        );
        return;
      }
      spans.add(span);
    }

    for (final node in content) {
      if (node is! Map) continue;
      switch (node['type']) {
        case 'text':
          final text = node['text'];
          if (text is! String) break;
          push(_withMarks(text, node['marks']));

        case 'hardBreak':
          push(const ExportSpan('\n'));

        case 'diaryLink':
          final attrs = node['attrs'];
          if (attrs is! Map) break;
          final label = attrs['label'];
          final id = attrs['id'];
          push(
            ExportSpan(
              label is String && label.isNotEmpty ? label : '未命名日记',
              diaryLinkId: id is String && id.isNotEmpty ? id : null,
            ),
          );

        default:
          final type = node['type'];
          if (type is String) unsupported.add(type);
      }
    }
    return spans;
  }

  static bool _sameStyle(ExportSpan a, ExportSpan b) =>
      a.bold == b.bold &&
      a.italic == b.italic &&
      a.strike == b.strike &&
      a.underline == b.underline &&
      a.code == b.code &&
      a.href == b.href &&
      a.diaryLinkId == b.diaryLinkId;

  static ExportSpan _withMarks(String text, dynamic marks) {
    var bold = false, italic = false, strike = false;
    var underline = false, code = false;
    String? href;

    if (marks is List) {
      for (final mark in marks) {
        if (mark is! Map) continue;
        switch (mark['type']) {
          case 'bold':
            bold = true;
          case 'italic':
            italic = true;
          case 'strike':
            strike = true;
          case 'underline':
            underline = true;
          case 'code':
            code = true;
          case 'link':
            final attrs = mark['attrs'];
            if (attrs is Map && attrs['href'] is String) {
              href = attrs['href'] as String;
            }
        }
      }
    }

    return ExportSpan(
      text,
      bold: bold,
      italic: italic,
      strike: strike,
      underline: underline,
      code: code,
      href: href,
    );
  }

  /// 代码块正文：内容是纯 text 节点，直接拼接（不认 mark）。
  static String _plainText(dynamic content) {
    if (content is! List) return '';
    final buf = StringBuffer();
    for (final node in content) {
      if (node is Map && node['text'] is String) {
        buf.write(node['text'] as String);
      }
    }
    return buf.toString();
  }
}
