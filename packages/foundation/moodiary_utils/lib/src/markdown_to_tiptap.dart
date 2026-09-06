import 'dart:convert';

import 'package:markdown/markdown.dart' as md;

class MarkdownToTiptap {
  const MarkdownToTiptap._();

  static const Set<String> _blockTags = {
    'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
    'ul', 'ol', 'li', 'blockquote', 'pre', 'hr',
    'table', 'thead', 'tbody', 'tr', 'th', 'td',
  };

  static String? convert(String markdown) {
    try {
      final nodes = md.Document(
        extensionSet: .gitHubFlavored,
        encodeHtml: false,
      ).parse(markdown);
      final content = _blocks(nodes);
      if (content.isEmpty) content.add({'type': 'paragraph'});
      return jsonEncode({'type': 'doc', 'content': content});
    } catch (_) {
      return null;
    }
  }

  static List<Map<String, dynamic>> _blocks(List<md.Node>? nodes) {
    final out = <Map<String, dynamic>>[];
    final inlineBuf = <md.Node>[];

    void flushInline() {
      if (inlineBuf.isEmpty) return;
      final blank = inlineBuf.every(
        (n) => n is md.Text && n.text.trim().isEmpty,
      );
      if (!blank) out.addAll(_paragraphLike(.of(inlineBuf)));
      inlineBuf.clear();
    }

    for (final n in nodes ?? const <md.Node>[]) {
      if (n is md.Element && _blockTags.contains(n.tag)) {
        flushInline();
        out.addAll(_block(n));
      } else {
        inlineBuf.add(n);
      }
    }
    flushInline();
    return out;
  }

  static List<Map<String, dynamic>> _block(md.Element el) {
    switch (el.tag) {
      case 'p':
        return _paragraphLike(el.children ?? const []);
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        final level = int.parse(el.tag.substring(1));
        final blocks = _paragraphLike(el.children ?? const [], heading: level);
        return blocks.isEmpty
            ? [
                {
                  'type': 'heading',
                  'attrs': {'level': level},
                },
              ]
            : blocks;
      case 'ul':
        return [_list(el, ordered: false)];
      case 'ol':
        return [_list(el, ordered: true)];
      case 'blockquote':
        final inner = _blocks(el.children);
        return [
          {
            'type': 'blockquote',
            'content': inner.isEmpty
                ? [
                    {'type': 'paragraph'},
                  ]
                : inner,
          },
        ];
      case 'pre':
        return [_codeBlock(el)];
      case 'hr':
        return [
          {'type': 'horizontalRule'},
        ];
      case 'table':
        return [_table(el)];
      default:
        return _blocks(el.children);
    }
  }

  static List<Map<String, dynamic>> _paragraphLike(
    List<md.Node> children, {
    int? heading,
  }) {
    final out = <Map<String, dynamic>>[];
    final buf = <Map<String, dynamic>>[];

    void flush() {
      if (buf.isEmpty) return;
      out.add(
        heading != null
            ? {
                'type': 'heading',
                'attrs': {'level': heading},
                'content': List.of(buf),
              }
            : {'type': 'paragraph', 'content': List.of(buf)},
      );
      buf.clear();
    }

    for (final n in children) {
      final media = _mediaIfAny(n);
      if (media != null) {
        flush();
        out.add(media);
      } else {
        _inline(n, const [], buf);
      }
    }
    flush();
    return out;
  }

  static void _inline(
    md.Node node,
    List<Map<String, dynamic>> marks,
    List<Map<String, dynamic>> buf,
  ) {
    if (node is md.Text) {
      if (node.text.isEmpty) return;
      buf.add({
        'type': 'text',
        'text': node.text,
        if (marks.isNotEmpty) 'marks': List.of(marks),
      });
      return;
    }
    if (node is! md.Element) return;
    final el = node;
    switch (el.tag) {
      case 'strong':
      case 'b':
        _inlineChildren(el, [...marks, _mark('bold')], buf);
      case 'em':
      case 'i':
        _inlineChildren(el, [...marks, _mark('italic')], buf);
      case 'del':
      case 's':
      case 'strike':
        _inlineChildren(el, [...marks, _mark('strike')], buf);
      case 'u':
      case 'ins':
        _inlineChildren(el, [...marks, _mark('underline')], buf);
      case 'code':
        final text = el.textContent;
        if (text.isNotEmpty) {
          buf.add({
            'type': 'text',
            'text': text,
            'marks': [...marks, _mark('code')],
          });
        }
      case 'a':
        final href = el.attributes['href'];
        final next = (href != null && href.isNotEmpty)
            ? [
                ...marks,
                {
                  'type': 'link',
                  'attrs': {'href': href},
                },
              ]
            : marks;
        _inlineChildren(el, next, buf);
      case 'br':
        buf.add({'type': 'hardBreak'});
      case 'img':
        return;
      default:
        _inlineChildren(el, marks, buf);
    }
  }

  static void _inlineChildren(
    md.Element el,
    List<Map<String, dynamic>> marks,
    List<Map<String, dynamic>> buf,
  ) {
    for (final c in el.children ?? const <md.Node>[]) {
      _inline(c, marks, buf);
    }
  }

  static Map<String, dynamic> _mark(String type) => {'type': type};

  static Map<String, dynamic>? _mediaIfAny(md.Node node) {
    if (node is! md.Element || node.tag != 'img') return null;
    final src = node.attributes['src'] ?? '';
    if (src.isEmpty) return null;
    if (src.startsWith('video-')) {
      return {
        'type': 'video',
        'attrs': {'filename': src},
      };
    }
    if (src.startsWith('audio-')) {
      return {
        'type': 'audio',
        'attrs': {'filename': src},
      };
    }
    final alt = node.attributes['alt'];
    return {
      'type': 'image',
      'attrs': {'src': src, if (alt != null && alt.isNotEmpty) 'alt': alt},
    };
  }

  static Map<String, dynamic> _list(md.Element el, {required bool ordered}) {
    final isTask = el.attributes['class'] == 'contains-task-list';
    final items = <Map<String, dynamic>>[];
    for (final c in el.children ?? const <md.Node>[]) {
      if (c is md.Element && c.tag == 'li') {
        items.add(_listItem(c, task: isTask));
      }
    }
    if (isTask) {
      return {'type': 'taskList', 'content': items};
    }
    final attrs = <String, dynamic>{};
    final start = el.attributes['start'];
    if (ordered && start != null) {
      attrs['start'] = int.tryParse(start) ?? 1;
    }
    return {
      'type': ordered ? 'orderedList' : 'bulletList',
      if (attrs.isNotEmpty) 'attrs': attrs,
      'content': items,
    };
  }

  static Map<String, dynamic> _listItem(md.Element li, {required bool task}) {
    var checked = false;
    final kids = <md.Node>[];
    for (final c in li.children ?? const <md.Node>[]) {
      if (task && c is md.Element && c.tag == 'input') {
        checked = c.attributes['checked'] == 'true';
        continue;
      }
      kids.add(c);
    }
    if (task && kids.isNotEmpty && kids.first is md.Text) {
      kids[0] = md.Text((kids.first as md.Text).text.trimLeft());
    }
    var content = _blocks(kids);
    if (content.isEmpty) {
      content = [
        {'type': 'paragraph'},
      ];
    } else if (content.first['type'] != 'paragraph') {
      content = [
        {'type': 'paragraph'},
        ...content,
      ];
    }
    if (task) {
      return {
        'type': 'taskItem',
        'attrs': {'checked': checked},
        'content': content,
      };
    }
    return {'type': 'listItem', 'content': content};
  }

  static Map<String, dynamic> _codeBlock(md.Element pre) {
    final code = (pre.children ?? const <md.Node>[])
        .whereType<md.Element>()
        .where((e) => e.tag == 'code')
        .firstOrNull;
    var text = code?.textContent ?? pre.textContent;
    if (text.endsWith('\n')) text = text.substring(0, text.length - 1);
    String? lang;
    final cls = code?.attributes['class'];
    if (cls != null && cls.startsWith('language-')) {
      lang = cls.substring('language-'.length);
    }
    return {
      'type': 'codeBlock',
      if (lang != null && lang.isNotEmpty) 'attrs': {'language': lang},
      if (text.isNotEmpty)
        'content': [
          {'type': 'text', 'text': text},
        ],
    };
  }

  static Map<String, dynamic> _table(md.Element el) {
    final rows = <Map<String, dynamic>>[];
    for (final section in el.children ?? const <md.Node>[]) {
      if (section is! md.Element) continue;
      if (section.tag != 'thead' && section.tag != 'tbody') continue;
      for (final tr in section.children ?? const <md.Node>[]) {
        if (tr is! md.Element || tr.tag != 'tr') continue;
        final cells = <Map<String, dynamic>>[];
        for (final cell in tr.children ?? const <md.Node>[]) {
          if (cell is! md.Element) continue;
          if (cell.tag != 'th' && cell.tag != 'td') continue;
          final buf = <Map<String, dynamic>>[];
          for (final c in cell.children ?? const <md.Node>[]) {
            _inline(c, const [], buf);
          }
          cells.add({
            'type': cell.tag == 'th' ? 'tableHeader' : 'tableCell',
            'content': [
              {'type': 'paragraph', if (buf.isNotEmpty) 'content': buf},
            ],
          });
        }
        if (cells.isNotEmpty) {
          rows.add({'type': 'tableRow', 'content': cells});
        }
      }
    }
    return {'type': 'table', 'content': rows};
  }
}
