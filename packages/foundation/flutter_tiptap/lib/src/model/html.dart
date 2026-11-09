part of '../model.dart';

/// HTML clipboard interchange for the editor schema. Rendering stays host-owned.
class TiptapHtmlCodec {
  TiptapHtmlCodec(this.schema);
  final Schema schema;

  bool _preserveWhitespace = false;
  Node parse(String source, {bool preserveWhitespace = false}) {
    _preserveWhitespace = preserveWhitespace;
    final fragment = html.parseFragment(source);
    final blocks = _blocks(fragment.nodes);
    return schema.node(
      'doc',
      attrs: {'v': 2},
      content: blocks.isEmpty ? [schema.node('paragraph')] : blocks,
    );
  }

  Slice parseSlice(String source) {
    final fragment = html.parseFragment(source);
    final root = fragment.querySelector('[data-pm-slice]');
    const inlineParents = {
      'a',
      'abbr',
      'acronym',
      'b',
      'cite',
      'code',
      'del',
      'em',
      'i',
      'ins',
      'kbd',
      'label',
      'output',
      'q',
      'ruby',
      's',
      'samp',
      'span',
      'strong',
      'sub',
      'sup',
      'time',
      'u',
      'tt',
      'var',
    };
    for (final br in fragment.querySelectorAll('br')) {
      if (br.parentNode?.nodes.last == br &&
          !inlineParents.contains(br.parent?.localName)) {
        br.remove();
      }
    }
    final doc = parse(
      fragment.nodes
          .map(
            (n) => n is dom.Element
                ? n.outerHtml
                : n is dom.Text
                ? _text(n.data)
                : '',
          )
          .join(),
      preserveWhitespace: root != null,
    );
    final depths = root?.attributes['data-pm-slice']?.split(' ');
    int open(Node node, bool end) {
      var depth = 0;
      while (!node.isLeaf &&
          !node.isText &&
          (depths != null ||
              !const {
                'table',
                'tableCell',
                'tableHeader',
              }.contains(node.type))) {
        depth++;
        if (node.content.isEmpty) break;
        node = end ? node.content.last : node.content.first;
      }
      return depth;
    }

    var content = doc.content;
    final wrappers = depths != null && depths.length > 2
        ? int.tryParse(depths[2]) ?? 0
        : 0;
    if (wrappers <= -2 && content.first.type == 'table') {
      content = content.first.content;
      if (wrappers <= -3 && content.isNotEmpty) content = content.first.content;
    }
    final start = open(content.first, false), end = open(content.last, true);
    return Slice(
      content,
      depths == null ? start : (int.tryParse(depths[0]) ?? 0).clamp(0, start),
      depths == null || depths.length < 2
          ? end
          : (int.tryParse(depths[1]) ?? 0).clamp(0, end),
    );
  }

  String plainText(Node doc, {int from = 0, int? to}) {
    to ??= doc.content.size;
    final out = StringBuffer();
    void walk(Node parent, int lo, int hi, int base) {
      var index = parent.content.indexAt(lo);
      var position = parent.content.positionAt(index);
      while (index < parent.childCount && position < hi) {
        final node = parent.child(index), end = position + node.nodeSize;
        if (end > lo) {
          final global = base + position;
          if (!node.isText &&
              node.schema.nodes[node.type]?.inline != true &&
              global > from) {
            out.write('\n\n');
          }
          if (node.isText) {
            out.write(
              node.text!.substring(
                math.max(0, lo - position),
                math.min(node.nodeSize, hi - position),
              ),
            );
          } else if (node.type == referenceNodeType) {
            out.write(node.attrs['label'] ?? node.attrs['id'] ?? '');
          } else if (node.type == 'hardBreak') {
            out.write('\n');
          } else if (!node.isLeaf) {
            walk(
              node,
              math.max(0, lo - position - 1),
              math.min(node.content.size, hi - position - 1),
              global + 1,
            );
          }
        }
        position = end;
        index++;
      }
    }

    walk(doc, from, to, 0);
    return out.toString();
  }

  String serialize(Node doc) =>
      doc.type == 'doc' ? doc.content.map(_node).join() : _node(doc);
  String serializeSlice(Slice slice) {
    var source = slice.content.map(_node).join();
    var wrappers = 0;
    if (slice.content.isNotEmpty && slice.content.first.type == 'tableRow') {
      source = '<table><tbody>$source</tbody></table>';
      wrappers = 2;
    } else if (slice.content.isNotEmpty &&
        const {'tableCell', 'tableHeader'}.contains(slice.content.first.type)) {
      source = '<table><tbody><tr>$source</tr></tbody></table>';
      wrappers = 3;
    }
    final fragment = html.parseFragment(source);
    if (fragment.nodes.firstOrNull case final dom.Element first) {
      first.attributes['data-pm-slice'] =
          '${slice.openStart} ${slice.openEnd}${wrappers == 0 ? '' : ' -$wrappers'} []';
    }
    return fragment.nodes
        .map(
          (n) => n is dom.Element
              ? n.outerHtml
              : n is dom.Text
              ? _text(n.data)
              : '',
        )
        .join();
  }

  static const _blockTags = {
    'p',
    'div',
    'section',
    'article',
    'header',
    'footer',
    'aside',
    'address',
    'main',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'blockquote',
    'pre',
    'ul',
    'ol',
    'li',
    'table',
    'hr',
    'img',
  };
  List<Node> _blocks(
    Iterable<dom.Node> source, [
    List<Mark> inherited = const [],
  ]) {
    final result = <Node>[], inline = <Node>[];
    void flush({bool force = false}) {
      final cleaned = _trim(inline);
      if (cleaned.isNotEmpty || force) {
        result.add(schema.node('paragraph', content: cleaned));
      }
      inline.clear();
    }

    void visit(dom.Node node, List<Mark> marks) {
      if (node is dom.Element && _blockTags.contains(node.localName)) {
        flush();
        result.addAll(_block(node, marks));
      } else if (node is dom.Element && node.localName == 'br') {
        inline.add(schema.node('hardBreak', marks: marks));
      } else {
        if (node is dom.Element &&
            node.querySelector(_blockTags.join(',')) != null) {
          for (final child in node.nodes) {
            visit(child, _marks(node, marks));
          }
        } else {
          inline.addAll(_inline(node, marks));
        }
      }
    }

    for (final node in source) {
      visit(node, inherited);
    }
    flush();
    return result;
  }

  List<Node> _trim(List<Node> nodes) {
    if (_preserveWhitespace) return nodes;
    final result = <Node>[];
    for (final node in nodes) {
      if (node.isText &&
          result.isNotEmpty &&
          ((result.last.isText && result.last.text!.endsWith(' ')) ||
              result.last.type == 'hardBreak')) {
        final text = node.text!.replaceFirst(RegExp(r'^ +'), '');
        if (text.isNotEmpty) result.add(node.withText(text));
      } else {
        result.add(node);
      }
    }
    while (result.isNotEmpty && result.first.isText) {
      final value = result.first.text!.replaceFirst(RegExp(r'^ +'), '');
      if (value.isNotEmpty) {
        result[0] = result.first.withText(value);
        break;
      }
      result.removeAt(0);
    }
    while (result.isNotEmpty && result.last.isText) {
      final value = result.last.text!.replaceFirst(RegExp(r' +$'), '');
      if (value.isNotEmpty) {
        result[result.length - 1] = result.last.withText(value);
        break;
      }
      result.removeLast();
    }
    return result;
  }

  List<Node> _block(dom.Element el, List<Mark> inherited) {
    inherited = _marks(el, inherited);
    final tag = el.localName!;
    if (tag == 'img') {
      final src = el.attributes['data-src'] ?? el.attributes['src'];
      if (src == null || src.isEmpty) return [];
      return [
        schema.node(
          'image',
          attrs: {
            'src': src,
            'name': _value(el, 'data-name') ?? _value(el, 'alt'),
            'widthPercent': _width(el),
          },
        ),
      ];
    }
    final kind = el.attributes['data-media'];
    if (tag == 'div' && (kind == 'video' || kind == 'audio')) {
      return [
        schema.node(
          kind!,
          attrs: {
            'src': _value(el, 'data-src'),
            'name': _value(el, 'data-name'),
            if (kind == 'video') 'widthPercent': _width(el),
          },
        ),
      ];
    }
    if (el.attributes['data-type'] == 'attachment') {
      return [
        schema.node(
          'attachment',
          attrs: {
            'src': _value(el, 'data-src'),
            'name': _value(el, 'data-name'),
            'mime': _value(el, 'data-mime'),
            'size': _size(el),
          },
        ),
      ];
    }
    if (tag == 'hr' || el.attributes['data-type'] == 'horizontalRule') {
      final variant = el.attributes['data-variant'];
      return [
        schema.node(
          'horizontalRule',
          attrs: {
            'variant':
                const {
                  'solid',
                  'dashed',
                  'dotted',
                  'double',
                  'wavy',
                  'text',
                }.contains(variant)
                ? variant
                : 'solid',
            'label': _value(el, 'data-label'),
          },
        ),
      ];
    }
    if (tag == 'pre') {
      final code = el.querySelector('code');
      final language = code?.classes
          .where((c) => c.startsWith('language-'))
          .firstOrNull
          ?.substring(9);
      final text = el.text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      return [
        schema.node(
          'codeBlock',
          attrs: {'language': language},
          content: [if (text.isNotEmpty) schema.node('text', text: text)],
        ),
      ];
    }
    if (tag == 'ul' || tag == 'ol') {
      final type = tag == 'ol'
          ? 'orderedList'
          : el.attributes['data-type'] == 'taskList'
          ? 'taskList'
          : 'bulletList';
      final items = <Node>[];
      for (final child in el.children) {
        if (child.localName == 'li') {
          final task = child.attributes['data-type'] == 'taskItem';
          final container = task ? child.querySelector('div') ?? child : child;
          var blocks = _blocks(
            container.nodes.where(
              (n) => n is! dom.Element || n.localName != 'label',
            ),
          );
          if (blocks.isEmpty || blocks.first.type != 'paragraph') {
            blocks = [schema.node('paragraph'), ...blocks];
          }
          items.add(
            schema.node(
              type == 'taskList' ? 'taskItem' : 'listItem',
              attrs: type == 'taskList'
                  ? {
                      'checked': const {
                        '',
                        'true',
                      }.contains(child.attributes['data-checked']),
                    }
                  : null,
              content: blocks,
            ),
          );
        } else if (child.localName == 'ul' || child.localName == 'ol') {
          final nested = _block(child, inherited);
          if (items.isNotEmpty) {
            items[items.length - 1] = items.last.copy(
              Fragment([...items.last.content, ...nested]),
            );
          }
        }
      }
      return items.isEmpty
          ? []
          : [
              schema.node(
                type,
                attrs: type == 'orderedList'
                    ? {'start': int.tryParse(el.attributes['start'] ?? '') ?? 1}
                    : null,
                content: items,
              ),
            ];
    }
    if (tag == 'table') {
      final rows = <Node>[];
      for (final row
          in el
              .querySelectorAll('tr')
              .where((r) => r.parent?.localName != 'table' || r.parent == el)) {
        var parent = row.parent;
        while (parent != null && parent.localName != 'table') {
          parent = parent.parent;
        }
        if (parent != el) continue;
        final cells = <Node>[];
        for (final cell in row.children.where(
          (c) => c.localName == 'td' || c.localName == 'th',
        )) {
          final blocks = _blocks(cell.nodes);
          final css = _css(cell);
          final widths = cell.attributes['colwidth']
              ?.split(',')
              .map(int.tryParse)
              .toList();
          cells.add(
            schema.node(
              cell.localName == 'th' ? 'tableHeader' : 'tableCell',
              attrs: {
                'colspan': int.tryParse(cell.attributes['colspan'] ?? '') ?? 1,
                'rowspan': int.tryParse(cell.attributes['rowspan'] ?? '') ?? 1,
                'colwidth':
                    widths != null && widths.every((w) => w != null && w > 0)
                    ? widths
                    : null,
                'align': css['text-align'],
              },
              content: blocks.isEmpty ? [schema.node('paragraph')] : blocks,
            ),
          );
        }
        rows.add(schema.node('tableRow', content: cells));
      }
      return rows.isEmpty ? [] : [schema.node('table', content: rows)];
    }
    if (tag == 'blockquote') {
      final blocks = _blocks(el.nodes, inherited);
      return [
        schema.node(
          'blockquote',
          content: blocks.isEmpty ? [schema.node('paragraph')] : blocks,
        ),
      ];
    }
    final heading = RegExp(r'^h([1-6])$').firstMatch(tag);
    if (tag == 'p' || heading != null) {
      final marks = _marks(el, inherited);
      final content = <Node>[];
      final out = <Node>[];
      void flush() {
        out.add(
          schema.node(
            heading == null ? 'paragraph' : 'heading',
            attrs: heading == null ? null : {'level': int.parse(heading[1]!)},
            content: _trim(content),
          ),
        );
        content.clear();
      }

      void visit(dom.Node child, List<Mark> marks) {
        if (child is dom.Element && child.localName == 'img') {
          flush();
          out.addAll(_block(child, marks));
        } else if (child is dom.Element && child.querySelector('img') != null) {
          for (final nested in child.nodes) {
            visit(nested, _marks(child, marks));
          }
        } else {
          content.addAll(_inline(child, marks));
        }
      }

      for (final child in el.nodes) {
        visit(child, marks);
      }
      if (content.isNotEmpty || out.isEmpty) flush();
      return out;
    }
    return _blocks(el.nodes, inherited);
  }

  List<Node> _inline(dom.Node node, List<Mark> marks) {
    if (node is dom.Text) {
      final value = _preserveWhitespace
          ? node.data.replaceAll(RegExp(r'[\r\n]'), ' ')
          : node.data.replaceAll(RegExp(r'[\t\r\n ]+'), ' ');
      return value.isEmpty
          ? []
          : [schema.node('text', text: value, marks: marks)];
    }
    if (node is! dom.Element ||
        const {
          'script',
          'style',
          'head',
          'meta',
          'link',
          'noscript',
        }.contains(node.localName)) {
      return [];
    }
    if (node.localName == 'br') return [schema.node('hardBreak', marks: marks)];
    if (node.attributes['data-type'] == referenceNodeType) {
      return [
        schema.node(
          referenceNodeType,
          attrs: {
            'id': _value(node, 'data-id'),
            'label': _value(node, 'data-label'),
          },
          marks: marks,
        ),
      ];
    }
    final next = _marks(node, marks);
    return [for (final child in node.nodes) ..._inline(child, next)];
  }

  List<Mark> _marks(dom.Element el, List<Mark> inherited) {
    var marks = inherited;
    void add(String name, [Map<String, Object?>? attrs]) {
      marks = schema.addMark(marks, schema.mark(name, attrs));
    }

    final tag = el.localName, css = _css(el), weight = css['font-weight'];
    if ((tag == 'b' && weight != 'normal') ||
        tag == 'strong' ||
        weight == 'bold' ||
        weight == 'bolder' ||
        (int.tryParse(weight ?? '') ?? 0) >= 500) {
      add('bold');
    }

    if (tag == 'em' || tag == 'i' || css['font-style'] == 'italic') {
      add('italic');
    }
    if (css['font-style'] == 'normal') {
      marks = marks.where((m) => m.type != 'italic').toList();
    }
    if (tag == 'u' || (css['text-decoration'] ?? '').contains('underline')) {
      add('underline');
    }
    if (const {'s', 'strike', 'del'}.contains(tag) ||
        (css['text-decoration'] ?? '').contains('line-through')) {
      add('strike');
    }
    if (tag == 'mark') add('highlight');
    if (tag == 'code') add('code');
    if (tag == 'a' &&
        el.attributes['href'] != null &&
        _allowedHref(el.attributes['href']!)) {
      add('link', {'href': el.attributes['href']});
    }
    return marks;
  }

  bool _allowedHref(String value) {
    final uri = value.replaceAll(
      RegExp(r'[\u0000-\u0020\u00a0\u1680\u180e\u2000-\u2029\u205f\u3000]'),
      '',
    );
    return uri.isEmpty ||
        RegExp(
          r'^(?:(?:https?|ftp|ftps|mailto|tel|callto|sms|cid|xmpp):|[^a-z]|[a-z0-9+.\-]+(?:[^a-z+.\-:]|$))',
          caseSensitive: false,
        ).hasMatch(uri);
  }

  num? _size(dom.Element el) {
    final value = num.tryParse(el.attributes['data-size'] ?? '');
    return value != null && value.isFinite && value >= 0 ? value : null;
  }

  Map<String, String> _css(dom.Element el) => {
    for (final declaration in (el.attributes['style'] ?? '').split(';'))
      if (declaration.contains(':'))
        declaration.split(':').first.trim().toLowerCase(): declaration
            .substring(declaration.indexOf(':') + 1)
            .trim()
            .toLowerCase(),
  };
  String? _value(dom.Element el, String name) =>
      el.attributes[name]?.isNotEmpty == true ? el.attributes[name] : null;
  num? _width(dom.Element el) {
    final value = num.tryParse(el.attributes['data-width-percent'] ?? '');
    return value?.isFinite == true ? value!.round().clamp(25, 100) : null;
  }

  static const _escape = HtmlEscape(HtmlEscapeMode.element);
  String _text(String value) => _escape.convert(value);
  String _attrs(Map<String, Object?> values) => values.entries
      .where((e) => e.value != null)
      .map(
        (e) => ' ${e.key}="${const HtmlEscape().convert(e.value.toString())}"',
      )
      .join();
  String _node(Node node) {
    final children = node.content.map(_node).join(), a = node.attrs;
    String wrap(String tag, [Map<String, Object?> attrs = const {}]) =>
        '<$tag${_attrs(attrs)}>$children</$tag>';
    if (node.isText) {
      var value = _text(node.text!);
      for (final mark in node.marks.reversed) {
        final tag = switch (mark.type) {
          'bold' => 'strong',
          'italic' => 'em',
          'strike' => 's',
          'underline' => 'u',
          'code' => 'code',
          'highlight' => 'mark',
          'link' => 'a',
          _ => 'span',
        };
        value =
            '<$tag${_attrs(mark.type == 'link' ? {'href': mark.attrs['href']} : const {})}>$value</$tag>';
      }
      return value;
    }
    return switch (node.type) {
      'paragraph' => wrap('p'),
      'heading' => wrap('h${a['level']}'),
      'blockquote' => wrap('blockquote'),
      'bulletList' => wrap('ul'),
      'orderedList' => wrap('ol', {'start': a['start']}),
      'taskList' => wrap('ul', {'data-type': 'taskList'}),
      'listItem' => wrap('li'),
      'taskItem' =>
        '<li${_attrs({'data-type': 'taskItem', 'data-checked': a['checked']})}><label><input type="checkbox"${a['checked'] == true ? ' checked="checked"' : ''}><span></span></label><div>$children</div></li>',
      'hardBreak' => '<br>',
      'codeBlock' =>
        '<pre><code${_attrs({'class': a['language'] == null ? null : 'language-${a['language']}'})}>${_text(node.textContent)}</code></pre>',
      'image' =>
        '<img${_attrs({'src': a['src'], 'data-name': a['name'], 'alt': a['name'], 'data-width-percent': a['widthPercent']})}>',
      'video' || 'audio' =>
        '<div${_attrs({'data-media': node.type, 'data-src': a['src'], 'data-name': a['name'], 'data-width-percent': a['widthPercent']})}></div>',
      'attachment' =>
        '<div${_attrs({'data-type': 'attachment', 'data-src': a['src'], 'data-name': a['name'], 'data-mime': a['mime'], 'data-size': a['size']})}>${_text((a['name'] ?? a['src'] ?? '').toString())}</div>',
      referenceNodeType =>
        '<span${_attrs({'data-type': referenceNodeType, 'data-id': a['id'], 'data-label': a['label']})}>${_text((a['label'] ?? a['id'] ?? '').toString())}</span>',
      'horizontalRule' =>
        '<div${_attrs({'data-type': 'horizontalRule', 'data-variant': a['variant'], 'data-label': a['label']})}>${a['variant'] == 'text' ? '<span>${_text((a['label'] ?? '').toString())}</span>' : '<hr>'}</div>',
      'table' => '<table><tbody>$children</tbody></table>',
      'tableRow' => wrap('tr'),
      'tableCell' || 'tableHeader' => wrap(
        node.type == 'tableCell' ? 'td' : 'th',
        {
          'colspan': a['colspan'],
          'rowspan': a['rowspan'],
          'colwidth': a['colwidth'] is List
              ? (a['colwidth']! as List).join(',')
              : null,
          'style': a['align'] == null ? null : 'text-align: ${a['align']}',
        },
      ),
      _ => children,
    };
  }
}
