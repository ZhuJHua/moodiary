part of '../model.dart';

final _linkDetector = linkify.Linkify();
final _linkSchemeWithSlashes = RegExp(
  r'^[a-z][a-z0-9+.-]*://',
  caseSensitive: false,
);
final _linkScheme = RegExp(r'^[a-z][a-z0-9+.-]*:', caseSensitive: false);
final _linkHostEnd = RegExp(r'[/?#:]');
final _linkIpv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
final _contactScheme = RegExp(r'^(mailto|tel|sms):', caseSensitive: false);
final _hrefScheme = RegExp(
  r'^([a-z][a-z0-9+.-]*):(?!\d)',
  caseSensitive: false,
);
final _leadingSlashes = RegExp(r'^/+');
final _linkWhitespace = RegExp(
  r'[\u0000-\u0020\u00a0\u1680\u180e\u2000-\u2029\u205f\u3000]',
);
final _linkWord = RegExp(
  r'[^\u0000-\u0020\u00a0\u1680\u180e\u2000-\u2029\u205f\u3000]+',
);
final _trailingLinkWhitespace = RegExp('${_linkWhitespace.pattern}+\$');
final _allowedLinkUri = RegExp(
  r'^(?:(?:http|https|ftp|ftps|mailto|tel|callto|sms|cid|xmpp):|[^a-z]|[a-z0-9+.\-]+(?:[^a-z+.\-:]|$))',
  caseSensitive: false,
);

bool _shouldAutoLink(String value) {
  if (_linkSchemeWithSlashes.hasMatch(value) ||
      (_linkScheme.hasMatch(value) && !value.contains('@'))) {
    return true;
  }
  final hostname = value.split('@').last.split(_linkHostEnd).first;
  return hostname.contains('.') && !_linkIpv4.hasMatch(hostname);
}

bool _isAllowedLink(String value) =>
    _allowedLinkUri.hasMatch(value.replaceAll(_linkWhitespace, ''));

String normalizeHref(String raw) {
  final href = raw.trim();
  if (href.isEmpty) return '';
  if (_contactScheme.hasMatch(href)) {
    return href;
  }
  final scheme = _hrefScheme.firstMatch(href);
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
  return 'https://${href.replaceFirst(_leadingSlashes, '')}';
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

  void _autolink(Transaction tr, {({int from, int to})? insertedRange}) {
    if (!tr.selection.empty) return;
    final pos = tr.doc.resolve(tr.selection.head);
    if (!pos.parent.isTextblock || pos.parent.type == 'codeBlock') return;
    if (pos.parentOffset == 0) return;
    final tail = pos.parent.content
        .cut(pos.parentOffset - 1, pos.parentOffset)
        .first
        .text;
    if (tail == null || !_linkWhitespace.hasMatch(tail)) return;
    final offset = math.max(0, pos.parentOffset - 2048);
    final text = pos.parent.content.cut(offset, pos.parentOffset).inlineText();
    if (insertedRange != null) _unlinkTrailingWhitespace(tr, insertedRange);
    final match = _linkWord
        .allMatches(text.replaceAll('\ufffc', ' '))
        .lastOrNull;
    if (match == null || (offset > 0 && match.start == 0)) return;
    _linkify(
      tr,
      match[0]!,
      pos.start() + offset + match.start,
      wholeWord: true,
    );
  }

  // Whitespace inserted at the end of a link leaves the link.
  void _unlinkTrailingWhitespace(Transaction tr, ({int from, int to}) range) {
    final end = tr.doc.resolve(range.to);
    if (!end.parent.isTextblock || end.nodeBefore?.isText != true) return;
    final start = math.max(range.from, end.start());
    if (start >= range.to) return;
    final text = end.parent.content
        .cut(start - end.start(), end.parentOffset)
        .inlineText();
    final whitespace = _trailingLinkWhitespace.firstMatch(text);
    if (whitespace == null) return;
    final from = start + whitespace.start;
    final links = tr.doc
        .slice(from, range.to)
        .content
        .expand((node) => node.marks)
        .where((mark) => mark.type == 'link')
        .toSet();
    if (links.isEmpty) return;
    final after = end.nodeAfter;
    if (after != null && after.marks.any(links.contains)) return;
    for (final mark in links) {
      tr.step(RemoveMarkStep(from, range.to, mark));
    }
    if (tr.selection.empty && tr.selection.head == range.to) {
      tr.setStoredMarks(
        (tr.storedMarks ?? end.marks)
            .where((mark) => mark.type != 'link')
            .toList(),
      );
    }
  }

  void _autolinkBeforeSplit(Transaction tr) {
    final index = tr.doc.rowIndexAt(tr.selection.head);
    if (index == 0) return;
    final row = tr.doc.rowAt(index - 1);
    if (!row.node.isTextblock || row.node.type == 'codeBlock') return;
    final offset = math.max(0, row.node.content.size - 2048);
    final text = row.node.content
        .cut(offset)
        .inlineText()
        .replaceAll('\ufffc', ' ');
    final match = _linkWord.allMatches(text).lastOrNull;
    if (match != null && (offset == 0 || match.start > 0)) {
      _linkify(
        tr,
        match[0]!,
        row.position + 1 + offset + match.start,
        wholeWord: true,
      );
    }
  }

  void _linkify(
    Transaction tr,
    String text,
    int start, {
    bool wholeWord = false,
    bool preserveLinks = false,
  }) {
    final tokens = _linkDetector.tokenize(text);
    if (wholeWord &&
        !(tokens.length == 1 && tokens.first.isLink ||
            tokens.length == 3 &&
                tokens[1].isLink &&
                const [
                  '()',
                  '[]',
                ].contains(tokens.first.value + tokens.last.value))) {
      return;
    }
    for (final token in tokens.where((token) => token.isLink)) {
      if (!_isAllowedLink(token.value) || !_shouldAutoLink(token.value)) {
        continue;
      }
      final from = start + token.start, to = start + token.end;
      final nodes = tr.doc.slice(from, to).content;
      if (nodes.any(
        (n) => n.marks.any(
          (m) =>
              m.type == 'code' ||
              (wholeWord || preserveLinks) && m.type == 'link',
        ),
      )) {
        continue;
      }
      final href = token.toHref(wholeWord ? 'https' : 'http');
      tr.step(
        AddMarkStep(from, to, tr.doc.schema.mark('link', {'href': href})),
      );
    }
  }
}
