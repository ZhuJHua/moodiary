import 'dart:convert';

import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'export_doc.dart';

typedef ResolveMediaPath = String Function(String kind, String name);

class TiptapToIr {
  const TiptapToIr._();

  static const _mediaPrefixes = {'image-', 'audio-', 'video-'};

  static ExportDoc convert({
    required String id,
    required String title,
    required DateTime time,
    required String content,
    required ResolveMediaPath resolvePath,
    DiaryMood mood = .neutral,
    DiaryWeather? weather,
    Place? place,
    List<String> tags = const [],
    String? categoryName,
  }) {
    final unsupported = <String>{};
    final blocks = <IrBlock>[];

    final doc = _tryDoc(content);
    if (doc != null) {
      _blocks(doc['content'], blocks, unsupported, resolvePath);
    } else if (content.trim().isNotEmpty) {
      blocks.add(.paragraph(spans: [irSpan(content)]));
    }

    return ExportDoc(
      id: id,
      title: title,
      time: time,
      mood: mood,
      weather: weather,
      place: place,
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
    } catch (_) {}
    return null;
  }

  static void _blocks(
    dynamic content,
    List<IrBlock> out,
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
    List<IrBlock> out,
    Set<String> unsupported,
    ResolveMediaPath resolve,
  ) {
    final attrs = node['attrs'];
    switch (node['type']) {
      case 'paragraph':
        final spans = _inline(node['content'], unsupported);
        out.add(.paragraph(spans: spans));

      case 'heading':
        final raw = (attrs is Map) ? attrs['level'] : null;
        final level = (raw is int) ? raw.clamp(1, 6) : 1;
        out.add(
          .heading(level: level, spans: _inline(node['content'], unsupported)),
        );

      case 'blockquote':
        final children = <IrBlock>[];
        _blocks(node['content'], children, unsupported, resolve);
        out.add(.quote(children: children));

      case 'bulletList':
        out.add(
          .list(
            ordered: false,
            start: 1,
            items: _items(node['content'], unsupported, resolve),
          ),
        );

      case 'orderedList':
        final rawStart = (attrs is Map) ? attrs['start'] : null;
        out.add(
          .list(
            ordered: true,
            start: rawStart is int ? rawStart : 1,
            items: _items(node['content'], unsupported, resolve),
          ),
        );

      case 'taskList':
        out.add(
          .list(
            ordered: false,
            start: 1,
            items: _items(node['content'], unsupported, resolve),
          ),
        );

      case 'codeBlock':
        final lang = (attrs is Map) ? attrs['language'] : null;
        out.add(
          .code(
            language: lang is String && lang.isNotEmpty ? lang : null,
            text: _plainText(node['content']),
          ),
        );

      case 'horizontalRule':
        out.add(const .divider());

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

  static List<IrListItem> _items(
    dynamic content,
    Set<String> unsupported,
    ResolveMediaPath resolve,
  ) {
    if (content is! List) return const [];
    final items = <IrListItem>[];
    for (final node in content) {
      if (node is! Map) continue;
      final type = node['type'];
      if (type != 'listItem' && type != 'taskItem') {
        if (type is String) unsupported.add(type);
        continue;
      }
      final children = <IrBlock>[];
      _blocks(node['content'], children, unsupported, resolve);
      final attrs = node['attrs'];
      final checked = (type == 'taskItem')
          ? ((attrs is Map && attrs['checked'] == true))
          : null;
      items.add(IrListItem(children: children, checked: checked));
    }
    return items;
  }

  static IrBlock _table(
    dynamic content,
    Set<String> unsupported,
    ResolveMediaPath resolve,
  ) {
    final rows = <IrRow>[];
    if (content is! List) return .table(rows: rows);
    for (final row in content) {
      if (row is! Map || row['type'] != 'tableRow') continue;
      final cells = <IrCell>[];
      final rowContent = row['content'];
      if (rowContent is List) {
        for (final cell in rowContent) {
          if (cell is! Map) continue;
          final isHeader = cell['type'] == 'tableHeader';
          if (!isHeader && cell['type'] != 'tableCell') continue;
          final attrs = cell['attrs'];
          final children = <IrBlock>[];
          _blocks(cell['content'], children, unsupported, resolve);
          final align = (attrs is Map) ? attrs['align'] : null;
          cells.add(
            IrCell(
              children: children,
              header: isHeader,
              colspan: _span(attrs, 'colspan'),
              rowspan: _span(attrs, 'rowspan'),
              align: align is String && align.isNotEmpty ? align : null,
            ),
          );
        }
      }
      rows.add(IrRow(cells: cells));
    }
    return .table(rows: rows);
  }

  static int _span(dynamic attrs, String key) {
    if (attrs is! Map) return 1;
    final v = attrs[key];
    return (v is int && v >= 1) ? v : 1;
  }

  static IrBlock? _image(dynamic attrs, ResolveMediaPath resolve) {
    if (attrs is! Map) return null;
    final src = attrs['src'];
    if (src is! String || src.isEmpty) return null;

    final alt = attrs['alt'];
    final wp = attrs['widthPercent'];

    if (_isExternal(src)) {
      return .image(
        path: src,
        alt: alt is String ? alt : null,
        widthPercent: wp is int ? wp : null,
        isExternal: true,
      );
    }
    return .image(
      path: resolve('image', src),
      alt: alt is String ? alt : null,
      widthPercent: wp is int ? wp : null,
      isExternal: false,
    );
  }

  static IrBlock? _media(String type, dynamic attrs, ResolveMediaPath resolve) {
    if (attrs is! Map) return null;
    final name = attrs['filename'];
    if (name is! String || name.isEmpty) return null;
    final isVideo = type == 'video';
    return .media(
      kind: isVideo ? 'video' : 'audio',
      filename: name,
      path: resolve(type, name),
      coverPath: isVideo ? resolve('thumbnail', name) : null,
    );
  }

  static bool _isExternal(String src) {
    if (_mediaPrefixes.any(src.startsWith)) return false;
    return src.startsWith('http://') || src.startsWith('https://');
  }

  static List<IrSpan> _inline(dynamic content, Set<String> unsupported) {
    final spans = <IrSpan>[];
    if (content is! List) return spans;

    void push(IrSpan span) {
      if (span.text.isEmpty) return;
      final last = spans.isEmpty ? null : spans.last;
      if (last != null && _sameStyle(last, span)) {
        spans[spans.length - 1] = irSpan(
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
          push(irSpan('\n'));

        case 'diaryLink':
          final attrs = node['attrs'];
          if (attrs is! Map) break;
          final label = attrs['label'];
          final id = attrs['id'];
          push(
            irSpan(
              label is String && label.isNotEmpty
                  ? label
                  : l10n.common.untitled,
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

  static bool _sameStyle(IrSpan a, IrSpan b) =>
      a.bold == b.bold &&
      a.italic == b.italic &&
      a.strike == b.strike &&
      a.underline == b.underline &&
      a.code == b.code &&
      a.href == b.href &&
      a.diaryLinkId == b.diaryLinkId;

  static IrSpan _withMarks(String text, dynamic marks) {
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

    return irSpan(
      text,
      bold: bold,
      italic: italic,
      strike: strike,
      underline: underline,
      code: code,
      href: href,
    );
  }

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
