part of '../model.dart';

String normalizeHref(String raw) {
  final href = raw.trim();
  if (href.isEmpty) return '';
  if (RegExp(r'^(mailto|tel|sms):', caseSensitive: false).hasMatch(href)) {
    return href;
  }
  final scheme = RegExp(
    r'^([a-z][a-z0-9+.-]*):(?!\d)',
    caseSensitive: false,
  ).firstMatch(href);
  if (scheme != null) {
    return {
          'http',
          'https',
          'mailto',
          'tel',
          'sms',
        }.contains(scheme[1]!.toLowerCase())
        ? href
        : '';
  }
  return 'https://${href.replaceFirst(RegExp(r'^/+'), '')}';
}

class LinkRange {
  const LinkRange(this.from, this.to, this.href);
  final int from, to;
  final String href;
}

LinkRange? linkAt(Node doc, int position, [int? to]) {
  final pos = doc.resolve(position);
  if (!pos.parent.isTextblock) return null;
  var offset = pos.start();
  LinkRange? range;
  for (final node in pos.parent.content) {
    final link = node.marks.where((m) => m.type == 'link').firstOrNull;
    if (link != null) {
      final href = link.attrs['href'] as String? ?? '';
      if (range != null && range.to == offset && range.href == href) {
        range = LinkRange(range.from, offset + node.nodeSize, href);
      } else {
        range = LinkRange(offset, offset + node.nodeSize, href);
      }
      if (range.from <= position && range.to >= (to ?? position)) {
        // Extend through adjacent text with the same link, including differently marked runs.
        var end = range.to;
        var index = pos.parent.content.indexAt(end - pos.start());
        while (index < pos.parent.childCount) {
          final next = pos.parent.child(index++);
          if (!next.marks.any(
            (m) => m.type == 'link' && m.attrs['href'] == href,
          )) {
            break;
          }
          end += next.nodeSize;
        }
        return LinkRange(range.from, end, href);
      }
    } else {
      range = null;
    }
    offset += node.nodeSize;
  }
  return null;
}

extension _LinkCommands on EditorCommands {
  void _removeLinks(Transaction tr, int from, int to) {
    final marks = <Mark>{};
    _visitSelected(
      EditorState(doc: tr.doc, selection: TextSelection(from, to)),
      (n) => marks.addAll(n.marks.where((m) => m.type == 'link')),
    );
    for (final mark in marks) {
      tr.step(RemoveMarkStep(from, to, mark));
    }
  }

  void _editLink(Transaction tr, String command, Map<String, dynamic> args) {
    _caretAfterSelectedNode(tr);
    final sel = tr.selection,
        range = linkAt(tr.doc, tr.selection.from, tr.selection.to);
    final from = sel.empty ? range?.from ?? sel.from : sel.from;
    final to = sel.empty ? range?.to ?? sel.to : sel.to;
    if (command == 'toggleLink') {
      final href = args['href'] as String? ?? '';
      if (normalizeHref(href).isEmpty ||
          tr.doc.resolve(sel.from).parent.type == 'codeBlock') {
        return;
      }
      final marks = tr.storedMarks ?? tr.doc.resolve(sel.head).marks;
      var active = marks.any(
        (m) => m.type == 'link' && m.attrs['href'] == href,
      );
      if (!sel.empty) {
        var seen = false;
        active = true;
        _visitSelected(EditorState(doc: tr.doc, selection: sel), (node) {
          seen = true;
          if (!node.marks.any(
            (m) => m.type == 'link' && m.attrs['href'] == href,
          )) {
            active = false;
          }
        });
        active = active && seen;
      }
      if (active) {
        _removeLinks(tr, from, to);
        tr.setStoredMarks(marks.where((m) => m.type != 'link').toList());
      } else if (sel.empty) {
        tr.setStoredMarks(
          tr.doc.schema.addMark(
            marks,
            tr.doc.schema.mark('link', {'href': href}),
          ),
        );
      } else {
        tr.step(
          AddMarkStep(
            sel.from,
            sel.to,
            tr.doc.schema.mark('link', {'href': href}),
          ),
        );
      }
      return;
    }
    if (command == 'unsetLink' || command == 'toggleLink' && range != null) {
      _removeLinks(tr, from, to);
      tr.setStoredMarks(
        tr.doc
            .resolve(tr.selection.head)
            .marks
            .where((m) => m.type != 'link')
            .toList(),
      );
      return;
    }
    final href = normalizeHref(args['href'] as String? ?? '');
    if (href.isEmpty || tr.doc.resolve(from).parent.type == 'codeBlock') return;
    final content = tr.doc.slice(from, to).content;
    final oldText = content
        .map((n) => n.textContent)
        .join(content.any((n) => n.isTextblock) ? ' ' : '');
    final supplied = args['text'] as String? ?? '';
    final text = supplied.isNotEmpty
        ? supplied
        : oldText.isNotEmpty
        ? oldText
        : href;
    if (from < to && oldText == text) {
      _removeLinks(tr, from, to);
      tr.step(
        AddMarkStep(from, to, tr.doc.schema.mark('link', {'href': href})),
      );
    } else {
      final marks = tr.doc
          .resolve(from)
          .marks
          .where((m) => m.type != 'link')
          .toList();
      tr.replace(
        from,
        to,
        Slice(
          Fragment([
            tr.doc.schema.node(
              'text',
              text: text,
              marks: tr.doc.schema.addMark(
                marks,
                tr.doc.schema.mark('link', {'href': href}),
              ),
            ),
          ]),
          0,
          0,
        ),
      );
    }
    tr.setSelection(TextSelection(from + text.length));
    tr.setStoredMarks(
      tr.doc
          .resolve(tr.selection.head)
          .marks
          .where((m) => m.type != 'link')
          .toList(),
    );
  }

  void _autolink(Transaction tr) {
    if (!tr.selection.empty) return;
    final pos = tr.doc.resolve(tr.selection.head);
    if (!pos.parent.isTextblock || pos.parent.type == 'codeBlock') return;
    if (pos.parentOffset == 0) return;
    final tail = pos.parent.content
        .cut(pos.parentOffset - 1, pos.parentOffset)
        .first
        .text;
    if (tail == null || !RegExp(r'\s').hasMatch(tail)) return;
    final offset = math.max(0, pos.parentOffset - 2048);
    final text = pos.parent.content
        .cut(offset, pos.parentOffset)
        .map((n) => n.text ?? '\ufffc')
        .join();
    final match = RegExp(r'(\S+)\s+$').firstMatch(text);
    if (match == null) return;
    _linkify(
      tr,
      match[1]!,
      pos.start() + offset + match.start,
      wholeWord: true,
    );
  }

  void _autolinkBeforeSplit(Transaction tr) {
    final index = tr.doc.rowIndexAt(tr.selection.head);
    if (index == 0) return;
    final row = tr.doc.rowAt(index - 1);
    if (!row.node.isTextblock || row.node.type == 'codeBlock') return;
    final text = row.node.content.map((n) => n.text ?? '\ufffc').join();
    final match = RegExp(r'(\S+)\s*$').firstMatch(text);
    if (match != null) {
      _linkify(tr, match[1]!, row.position + 1 + match.start, wholeWord: true);
    }
  }

  void _linkify(
    Transaction tr,
    String text,
    int start, {
    bool wholeWord = false,
    String protocol = 'https',
  }) {
    final pattern = RegExp(
      r'''(?:https?://|www\.)[^\s<>]+|[\w.+-]+@[\w-]+(?:\.[\w-]+)+|(?:[a-zA-Z0-9-]+\.)+(?:com|org|net|io|dev|app|cn|co|uk|edu|gov|me|info)(?![a-zA-Z0-9-])(?:[/:?#][^\s<>]*)?''',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(text)) {
      var value = match[0]!.replaceFirst(RegExp(r'[.,!?;:]+$'), '');
      for (final pair in [('(', ')'), ('[', ']'), ('{', '}')]) {
        while (value.endsWith(pair.$2) &&
            pair.$2.allMatches(value).length >
                pair.$1.allMatches(value).length) {
          value = value.substring(0, value.length - 1);
        }
      }
      if (wholeWord &&
          !(text == value || text == '($value)' || text == '[$value]')) {
        continue;
      }
      if (value.isEmpty) {
        continue;
      }
      if (match.start > 0 && RegExp(r'[\w@]').hasMatch(text[match.start - 1])) {
        continue;
      }
      final from = start + match.start, to = from + value.length;
      final nodes = tr.doc.slice(from, to).content;
      if (nodes.any(
        (n) => n.marks.any((m) => m.type == 'code' || m.type == 'link'),
      )) {
        continue;
      }
      final href = value.contains('@') && !value.contains('://')
          ? 'mailto:$value'
          : value.contains('://')
          ? value
          : '$protocol://$value';
      tr.step(
        AddMarkStep(from, to, tr.doc.schema.mark('link', {'href': href})),
      );
    }
  }
}
