part of '../model.dart';

extension _PasteCommands on EditorCommands {
  void _pasteText(Transaction tr, String text, {bool plain = false}) {
    final pos = tr.doc.resolve(tr.selection.from), schema = tr.doc.schema;
    if (pos.parent.type == 'codeBlock') {
      _insertText(
        EditorState(doc: tr.doc, selection: tr.selection),
        tr,
        text,
        committed: false,
      );
      return;
    }
    if (!plain &&
        !tr.selection.empty &&
        RegExp(
          r'^(?:https?://|www\.)[^\s]+$|^[\w.+-]+@[\w-]+(?:\.[\w-]+)+$|^(?:[a-zA-Z0-9-]+\.)+(?:com|org|net|io|dev|app|cn|co|uk|edu|gov|me|info)$',
        ).hasMatch(text)) {
      final href = text.contains('@') && !text.contains('://')
          ? 'mailto:$text'
          : text.contains('://')
          ? text
          : 'https://$text';
      tr.step(
        AddMarkStep(
          tr.selection.from,
          tr.selection.to,
          schema.mark('link', {'href': href}),
        ),
      );
      return;
    }
    final parts = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split(RegExp(r'\n+'));
    final marks = pos.marks;
    final content = Fragment(
      parts.map(
        (s) => schema.node(
          'paragraph',
          content: s.isEmpty
              ? []
              : [schema.node('text', text: s, marks: marks)],
        ),
      ),
    );
    final from = tr.selection.from, to = tr.selection.to;
    _replacePasteRange(tr, from, to, Slice(content, 1, 1));
    final end = tr.mapping.map(to, 1);
    tr.setSelection(Selection.near(tr.doc, end));
    if (plain) return;
    for (final row in tr.doc.rows(
      from: tr.doc.rowIndexAt(from),
      to: tr.doc.rowIndexAt(end) + 1,
    )) {
      if (row.node.isTextblock) {
        _linkify(
          tr,
          row.node.content.map((n) => n.text ?? '\ufffc').join(),
          row.position + 1,
          protocol: 'http',
        );
      }
    }
  }
}

// ProseMirror's replaceRange expansion for clipboard slices. The frontier fitter
// alone intentionally drops open wrappers; paste must first preserve defining
// list items, quotes, headings and code blocks. See NOTICE.
bool _definesPasteContext(Node node) => const {
  'heading',
  'listItem',
  'taskItem',
  'blockquote',
  'codeBlock',
}.contains(node.type);

void _replacePasteRange(Transaction tr, int from, int to, Slice slice) {
  if (slice.size == 0) {
    tr.replace(from, to);
    return;
  }
  final a = tr.doc.resolve(from), b = tr.doc.resolve(to);
  if (slice.openStart == 0 &&
      slice.openEnd == 0 &&
      a.start() == b.start() &&
      a.parent.canReplace(a.index(), b.index(), slice.content)) {
    tr.step(ReplaceStep(from, to, slice));
    return;
  }
  final targets = <int>[];
  for (var d = math.min(a.depth, b.depth); d >= 0; d--) {
    final start = a.start(d);
    if (start < from - (a.depth - d) || b.end(d) > to + (b.depth - d)) break;
    if (start == b.start(d) ||
        (d == a.depth &&
            d == b.depth &&
            a.parent.isTextblock &&
            b.parent.isTextblock &&
            d > 0 &&
            b.start(d - 1) == start - 1)) {
      targets.add(d);
    }
  }
  if (targets.isNotEmpty && targets.last == 0) targets.removeLast();
  var preferredTarget = -(a.depth + 1);
  targets.insert(0, preferredTarget);
  for (var d = a.depth, pos = from - 1; d > 0; d--, pos--) {
    if (_definesPasteContext(a.node(d))) break;
    if (targets.contains(d)) {
      preferredTarget = d;
    } else if (a.before(d) == pos) {
      targets.insert(1, -d);
    }
  }
  final preferredTargetIndex = targets.indexOf(preferredTarget);
  final left = <Node>[];
  var content = slice.content;
  for (var d = 0; ; d++) {
    if (content.isEmpty) break;
    final node = content.first;
    left.add(node);
    if (d == slice.openStart) break;
    content = node.content;
  }
  var preferredDepth = slice.openStart;
  for (var d = preferredDepth - 1; d >= 0; d--) {
    final node = left[d],
        defining = _definesPasteContext(left[d]),
        context = a.node(preferredTarget.abs() - 1);
    if (defining &&
        (node.type != context.type ||
            !_equal(node.attrs, context.attrs) ||
            !_equal(node.marks, context.marks))) {
      preferredDepth = d;
    } else if (defining || !node.isTextblock) {
      break;
    }
  }
  for (var j = slice.openStart; j >= 0; j--) {
    final open = (j + preferredDepth + 1) % (slice.openStart + 1);
    if (open >= left.length) continue;
    final insert = left[open];
    for (var i = 0; i < targets.length; i++) {
      var target = targets[(i + preferredTargetIndex) % targets.length];
      final expand = target > 0;
      target = target.abs();
      final parent = a.node(target - 1), index = a.index(target - 1);
      // canReplaceWith checks the type, without requiring the open content to
      // already be valid. ContentMatch provides precisely that check here.
      final match = parent.contentMatchAt(index).matchType(insert.type);
      if (match?.matchFragment(parent.content, start: index)?.validEnd !=
          true) {
        continue;
      }
      final fragment = _closePasteFragment(
        slice.content,
        0,
        slice.openStart,
        open,
      );
      tr.replace(
        a.before(target),
        expand ? b.after(target) : to,
        Slice(fragment, open, slice.openEnd),
      );
      return;
    }
  }
  final steps = tr.steps.length;
  for (var i = targets.length - 1; i >= 0; i--) {
    tr.replace(from, to, slice);
    if (tr.steps.length > steps) break;
    final depth = targets[i];
    if (depth < 0) continue;
    from = a.before(depth);
    to = b.after(depth);
  }
}

Fragment _closePasteFragment(
  Fragment fragment,
  int depth,
  int oldOpen,
  int newOpen, [
  Node? parent,
]) {
  if (depth < oldOpen) {
    final first = fragment.first;
    fragment = fragment.replaceChild(
      0,
      first.copy(
        _closePasteFragment(first.content, depth + 1, oldOpen, newOpen, first),
      ),
    );
  }
  if (depth > newOpen) {
    final match = parent!.contentMatchAt(0);
    final start = match.fillBefore(fragment)!.append(fragment);
    fragment = start.append(
      match.matchFragment(start)!.fillBefore(Fragment.empty, toEnd: true)!,
    );
  }
  return fragment;
}
