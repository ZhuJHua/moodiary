part of '../model.dart';

class _NodeRange {
  const _NodeRange(this.from, this.to, this.depth);
  final ResolvedPos from, to;
  final int depth;
  Node get parent => from.node(depth);
  int get start => from.before(depth + 1);
  int get end => to.after(depth + 1);
  int get startIndex => from.index(depth);
  int get endIndex => to.indexAfter(depth);
}

_NodeRange? _blockRange(
  Node doc,
  Selection selection, [
  bool Function(Node)? predicate,
]) {
  final a = doc.resolve(selection.from), b = doc.resolve(selection.to);
  for (
    var d = a.depth - (a.parent.isTextblock || a.pos == b.pos ? 1 : 0);
    d >= 0;
    d--
  ) {
    if (b.pos <= a.end(d) && (predicate == null || predicate(a.node(d)))) {
      return _NodeRange(a, b, d);
    }
  }
  return null;
}

int? _liftTarget(_NodeRange range) {
  final content = range.parent.content.cutByIndex(
    range.startIndex,
    range.endIndex,
  );
  var before = 0, after = 0;
  for (var d = range.depth; d >= 0; d--) {
    final node = range.from.node(d),
        start = range.from.index(d) + before,
        end = range.to.indexAfter(d) - after;
    if (d < range.depth && node.canReplace(start, end, content)) return d;
    if (node.type == 'tableCell' ||
        node.type == 'tableHeader' ||
        node.type == 'table') {
      break;
    }
    if (d == 0 ||
        !((start == 0 || node.canReplace(start, node.childCount)) &&
            (end == node.childCount || node.canReplace(0, end)))) {
      break;
    }
    if (start > 0) before = 1;
    if (end < node.childCount) after = 1;
  }
  return null;
}

void _liftRange(Transaction tr, _NodeRange range, int target) {
  final a = range.from, b = range.to, depth = range.depth;
  final gapStart = a.before(depth + 1), gapEnd = b.after(depth + 1);
  var start = gapStart, end = gapEnd, openStart = 0, openEnd = 0;
  var before = Fragment.empty, after = Fragment.empty, splitting = false;
  for (var d = depth; d > target; d--) {
    if (splitting || a.index(d) > 0) {
      splitting = true;
      before = Fragment([a.node(d).copy(before)]);
      openStart++;
    } else {
      start--;
    }
  }
  splitting = false;
  for (var d = depth; d > target; d--) {
    if (splitting || b.after(d + 1) < b.end(d)) {
      splitting = true;
      after = Fragment([b.node(d).copy(after)]);
      openEnd++;
    } else {
      end++;
    }
  }
  tr.step(
    ReplaceAroundStep(
      start,
      end,
      gapStart,
      gapEnd,
      Slice(before.append(after), openStart, openEnd),
      before.size - openStart,
    ),
  );
}

List<(String, Map<String, Object?>?)>? _findWrapping(
  _NodeRange range,
  String type,
  Map<String, Object?>? attrs, [
  _NodeRange? inner,
]) {
  inner ??= range;
  final schema = range.parent.schema, parent = range.parent;
  final around = parent.contentMatchAt(range.startIndex).findWrapping(type);
  if (around == null) return null;
  final outer = around.isEmpty ? type : around.first;
  if (!parent.canReplace(
    range.startIndex,
    range.endIndex,
    Fragment([schema.node(outer)]),
  )) {
    return null;
  }
  final inside = schema
      .contentMatch(type)
      .findWrapping(inner.parent.child(inner.startIndex).type);
  if (inside == null) return null;
  final last = inside.isEmpty ? type : inside.last;
  final match = schema
      .contentMatch(last)
      .matchFragment(
        inner.parent.content,
        start: inner.startIndex,
        end: inner.endIndex,
      );
  if (match?.validEnd != true) return null;
  return [
    ...around.map((t) => (t, null)),
    (type, attrs),
    ...inside.map((t) => (t, null)),
  ];
}

void _splitAt(Transaction tr, int pos, int depth, [List<Node?>? types]) {
  final resolved = tr.doc.resolve(pos);
  var before = Fragment.empty, after = Fragment.empty;
  for (
    var d = resolved.depth, i = depth - 1;
    d > resolved.depth - depth;
    d--, i--
  ) {
    before = Fragment([resolved.node(d).copy(before)]);
    after = Fragment([(types?[i] ?? resolved.node(d)).copy(after)]);
  }
  tr.step(ReplaceStep(pos, pos, Slice(before.append(after), depth, depth)));
}

bool _canJoin(Node doc, int pos) {
  final resolved = doc.resolve(pos),
      a = resolved.nodeBefore,
      b = resolved.nodeAfter;
  return a != null &&
      b != null &&
      !a.isLeaf &&
      a.canReplace(a.childCount, a.childCount, b.content) &&
      resolved.parent.canReplace(resolved.index(), resolved.index() + 1);
}

void _joinAt(Transaction tr, int pos, [int depth = 1]) =>
    tr.step(ReplaceStep(pos - depth, pos + depth, Slice.empty));

class _SetNodeStep extends Step {
  const _SetNodeStep(this.position, this.node);
  final int position;
  final Node node;
  @override
  int get changedFrom => position;
  @override
  int get changedTo => position;
  @override
  StepMap getMap() => StepMap.empty;
  @override
  StepResult apply(Node doc) {
    final resolved = doc.resolve(position);
    Node visit(int depth) {
      final parent = resolved.node(depth), index = resolved.index(depth);
      return parent.copy(
        parent.content.replaceChild(
          index,
          depth == resolved.depth ? node : visit(depth + 1),
        ),
      );
    }

    return StepResult(
      visit(0),
      BlockRange(
        resolved.blockIndex,
        resolved.blockIndex + 1,
        resolved.blockIndex + 1,
      ),
    );
  }
}

bool _isList(String type) =>
    const {'bulletList', 'orderedList', 'taskList'}.contains(type);
bool _isItem(String type) => type == 'listItem' || type == 'taskItem';

extension _NestedCommands on EditorCommands {
  int? _ancestor(ResolvedPos pos, bool Function(String) predicate) {
    for (var d = pos.depth; d > 0; d--) {
      if (predicate(pos.node(d).type)) return d;
    }
    return null;
  }

  bool _lift(Transaction tr, {bool list = false}) {
    var range = _blockRange(
      tr.doc,
      tr.selection,
      list ? (n) => _isList(n.type) : null,
    );
    if (range == null) return false;
    if (!list) {
      final target = _liftTarget(range);
      if (target == null) return false;
      _liftRange(tr, range, target);
      return true;
    }
    final itemType = range.parent.firstItemType;
    if (range.depth > 0 && range.from.node(range.depth - 1).type == itemType) {
      final end = range.end, endOfList = range.to.end(range.depth);
      if (end < endOfList) {
        tr.step(
          ReplaceAroundStep(
            end - 1,
            endOfList,
            end,
            endOfList,
            Slice(
              Fragment([
                tr.doc.schema.node(
                  itemType,
                  content: [range.parent.copy(Fragment.empty)],
                ),
              ]),
              1,
              0,
            ),
            1,
          ),
        );
        range = _NodeRange(
          tr.doc.resolve(range.from.pos),
          tr.doc.resolve(endOfList),
          range.depth,
        );
      }
      final target = _liftTarget(range);
      if (target == null) return false;
      _liftRange(tr, range, target);
      final after = (tr.mapping.map(end, -1) - 1).clamp(0, tr.doc.content.size);
      if (_canJoin(tr.doc, after) &&
          tr.doc.resolve(after).nodeBefore!.type ==
              tr.doc.resolve(after).nodeAfter!.type) {
        _joinAt(tr, after);
      }
    } else {
      final listNode = range.parent;
      for (
        var pos = range.end, i = range.endIndex - 1;
        i > range.startIndex;
        i--
      ) {
        pos -= listNode.child(i).nodeSize;
        tr.replace(pos - 1, pos + 1);
      }
      final start = range.start, item = tr.doc.nodeAt(start)!;
      final atStart = range.startIndex == 0,
          atEnd = range.endIndex == listNode.childCount;
      final before = atStart
          ? Fragment.empty
          : Fragment([listNode.copy(Fragment.empty)]);
      final after = atEnd
          ? Fragment.empty
          : Fragment([listNode.copy(Fragment.empty)]);
      tr.step(
        ReplaceAroundStep(
          start - (atStart ? 1 : 0),
          start + item.nodeSize + (atEnd ? 1 : 0),
          start + 1,
          start + item.nodeSize - 1,
          Slice(before.append(after), atStart ? 0 : 1, atEnd ? 0 : 1),
          atStart ? 0 : 1,
        ),
      );
    }
    return true;
  }

  void _sink(Transaction tr) {
    final range = _blockRange(tr.doc, tr.selection, (n) => _isList(n.type));
    if (range == null || range.startIndex == 0) return;
    final before = range.parent.child(range.startIndex - 1);
    final nested = before.content.last.type == range.parent.type;
    final type = range.parent.firstItemType;
    final inner = nested
        ? Fragment([tr.doc.schema.node(type)])
        : Fragment.empty;
    final slice = Slice(
      Fragment([
        tr.doc.schema.node(
          type,
          content: [tr.doc.schema.node(range.parent.type, content: inner)],
        ),
      ]),
      nested ? 3 : 1,
      0,
    );
    tr.step(
      ReplaceAroundStep(
        range.start - (nested ? 3 : 1),
        range.end,
        range.start,
        range.end,
        slice,
        1,
      ),
    );
  }

  bool _wrap(
    Transaction tr,
    String type,
    Map<String, Object?>? attrs, {
    bool list = false,
  }) {
    var range = _blockRange(tr.doc, tr.selection);
    if (range == null) return false;
    var outer = range, join = false;
    if (list &&
        range.depth >= 2 &&
        tr.doc.schema.compatibleContent(
          range.from.node(range.depth - 1).type,
          type,
        ) &&
        range.startIndex == 0) {
      if (range.from.index(range.depth - 1) == 0) return false;
      final insert = tr.doc.resolve(range.start - 2);
      outer = _NodeRange(insert, insert, range.depth);
      if (range.endIndex < range.parent.childCount) {
        range = _NodeRange(
          range.from,
          tr.doc.resolve(range.to.end(range.depth)),
          range.depth,
        );
      }
      join = true;
    }
    final wrappers = _findWrapping(outer, type, attrs, range);
    if (wrappers == null) return false;
    var content = Fragment.empty;
    for (final (name, values) in wrappers.reversed) {
      content = Fragment([
        tr.doc.schema.node(name, attrs: values, content: content),
      ]);
    }
    tr.step(
      ReplaceAroundStep(
        range.start - (join ? 2 : 0),
        range.end,
        range.start,
        range.end,
        Slice(content, 0, 0),
        wrappers.length,
      ),
    );
    if (list) {
      final found = wrappers.indexWhere((w) => w.$1 == type) + 1;
      final splitDepth = wrappers.length - found;
      var splitPos = range.start + wrappers.length - (join ? 2 : 0);
      for (var i = range.startIndex; i < range.endIndex; i++) {
        if (i > range.startIndex && splitDepth > 0) {
          _splitAt(tr, splitPos, splitDepth);
          splitPos += 2 * splitDepth;
        }
        splitPos += range.parent.child(i).nodeSize;
      }
    }
    return true;
  }

  void _toggleList(Transaction tr, String type) {
    final pos = tr.doc.resolve(tr.selection.from),
        depth = _ancestor(tr.doc.resolve(tr.selection.from), _isList);
    if (depth != null) {
      final list = pos.node(depth);
      if (list.type == type) {
        _lift(tr, list: true);
        return;
      }
      final item = type == 'taskList' ? 'taskItem' : 'listItem';
      final content = list.content.map(
        (n) => tr.doc.schema.node(item, content: n.content),
      );
      tr.step(
        _SetNodeStep(
          pos.before(depth),
          tr.doc.schema.node(type, content: content),
        ),
      );
    } else {
      if (pos.parent.type != 'paragraph') {
        _setBlock(
          EditorState(doc: tr.doc, selection: tr.selection),
          tr,
          'paragraph',
          const {},
        );
      }
      _wrap(tr, type, null, list: true);
    }
    _joinLists(tr, type);
  }

  void _joinLists(Transaction tr, String type) {
    var resolved = tr.doc.resolve(tr.selection.from),
        depth = _ancestor(tr.doc.resolve(tr.selection.from), (t) => t == type);
    if (depth == null) return;
    var start = resolved.before(depth);
    final before = tr.doc.resolve(start).nodeBefore;
    if (before?.type == type && _canJoin(tr.doc, start)) _joinAt(tr, start);
    resolved = tr.doc.resolve(tr.selection.from);
    depth = _ancestor(resolved, (t) => t == type);
    if (depth == null) return;
    start = resolved.after(depth);
    if (tr.doc.resolve(start).nodeAfter?.type == type &&
        _canJoin(tr.doc, start)) {
      _joinAt(tr, start);
    }
  }

  bool _splitItem(Transaction tr) {
    var pos = tr.doc.resolve(tr.selection.from);
    final end = tr.doc.resolve(tr.selection.to);
    if (tr.selection is NodeSelection || pos.start() != end.start()) {
      return false;
    }
    final marks =
        tr.storedMarks ?? (end.parentOffset > 0 ? pos.marks : const <Mark>[]);
    if (pos.depth < 2 ||
        !_isItem(pos.node(pos.depth - 1).type) ||
        !pos.parent.isTextblock) {
      return false;
    }
    if (pos.parent.content.isEmpty &&
        pos.indexAfter(pos.depth - 1) == pos.node(pos.depth - 1).childCount) {
      final item = pos.node(pos.depth - 1);
      if (pos.depth < 4 ||
          pos.node(pos.depth - 3).type != item.type ||
          pos.index(pos.depth - 2) != pos.node(pos.depth - 2).childCount - 1) {
        return _lift(tr, list: true);
      }
      final before = pos.index(pos.depth - 1) != 0
          ? 1
          : pos.index(pos.depth - 2) != 0
          ? 2
          : 3;
      final after =
          pos.indexAfter(pos.depth - 1) < pos.node(pos.depth - 2).childCount
          ? 1
          : pos.indexAfter(pos.depth - 2) < pos.node(pos.depth - 3).childCount
          ? 2
          : 3;
      var wrap = Fragment.empty;
      for (var d = pos.depth - before; d >= pos.depth - 3; d--) {
        wrap = Fragment([pos.node(d).copy(wrap)]);
      }
      wrap = wrap.append(Fragment([tr.doc.schema.createAndFill(item.type)!]));
      final start = pos.before(pos.depth - before + 1);
      tr.replace(
        start,
        pos.after(pos.depth - after),
        Slice(wrap, 4 - before, 0),
      );
      // Find the first empty textblock after the retained left spine.
      Selection? find(Node node, int offset) {
        if (node.isTextblock) {
          return node.content.isEmpty && offset + 1 >= start
              ? TextSelection(offset + 1)
              : null;
        }
        if (node.isLeaf) return null;
        for (
          var i = node.content.indexAt(
            (start - offset - 1).clamp(0, node.content.size),
          );
          i < node.childCount;
          i++
        ) {
          final found = find(
            node.child(i),
            offset + 1 + node.content.positionAt(i),
          );
          if (found != null) return found;
        }
        return null;
      }

      final selection = find(tr.doc, -1);
      if (selection != null) tr.setSelection(selection);
      return true;
    }
    // A new item must begin with a paragraph, so a later heading or code
    // textblock cannot split into one.
    if (pos.parent.type != 'paragraph') return false;
    if (!tr.selection.empty) {
      tr.replace(tr.selection.from, tr.selection.to);
    }
    pos = tr.doc.resolve(tr.selection.from);
    final item = pos.node(pos.depth - 1);
    final next = pos.parentOffset == pos.parent.content.size
        ? tr.doc.schema.node('paragraph')
        : null;
    final atStart = pos.parentOffset == 0 && pos.index(pos.depth - 1) == 0;
    _splitAt(tr, pos.pos, 2, [
      atStart ? item : tr.doc.schema.node(item.type),
      next,
    ]);
    if (atStart) {
      tr.step(
        _SetNodeStep(
          pos.before(pos.depth - 1),
          item
              .withAttrs(tr.doc.schema.nodes[item.type]!.attrs)
              .copy(tr.doc.nodeAt(pos.before(pos.depth - 1))!.content),
        ),
      );
    }
    tr.setSelection(TextSelection(pos.pos + 4));
    tr.setStoredMarks(
      marks
          .where((m) => tr.doc.schema.marks[m.type]?.keepOnSplit != false)
          .toList(),
    );
    return true;
  }

  bool _codeIndent(Transaction tr, {required bool outdent}) {
    final selection = tr.selection, pos = tr.doc.resolve(tr.selection.from);
    if (pos.parent.type != 'codeBlock' ||
        tr.doc.resolve(selection.to).start() != pos.start()) {
      return false;
    }
    final text = pos.parent.textContent, start = pos.start();
    final from = selection.from == start
        ? 0
        : text.lastIndexOf('\n', selection.from - start - 1) + 1;
    final end = selection.to - start;
    final lines = <int>[from];
    for (
      var i = text.indexOf('\n', from);
      i >= 0 && i + 1 < end;
      i = text.indexOf('\n', i + 1)
    ) {
      lines.add(i + 1);
    }
    for (final line in lines.reversed) {
      final count = outdent
          ? (text.startsWith('\t', line)
                ? 1
                : RegExp(r'^ {1,2}')
                          .stringMatch(text.substring(line))
                          ?.length ??
                      0)
          : 0;
      if (outdent && count == 0) continue;
      tr.replace(
        start + line,
        start + line + count,
        outdent
            ? Slice.empty
            : Slice(Fragment([tr.doc.schema.node('text', text: '  ')]), 0, 0),
      );
    }
    tr.setSelection(
      TextSelection(
        tr.mapping.map(selection.anchor),
        tr.mapping.map(selection.head),
      ),
    );
    return true;
  }

  bool _codeEnter(Transaction tr, {bool exit = false}) {
    final pos = tr.doc.resolve(tr.selection.from);
    if (pos.parent.type != 'codeBlock') return false;
    final trailingLines =
        !exit &&
            tr.selection.empty &&
            pos.parentOffset == pos.parent.content.size
        ? RegExp(r'\n[ \t]*\n[ \t]*$').firstMatch(pos.parent.textContent)
        : null;
    if (exit || trailingLines != null) {
      final current = tr.doc.resolve(tr.selection.from),
          after = current.after();
      final parent = current.node(current.depth - 1),
          index = current.indexAfter(current.depth - 1);
      if (!parent.canReplace(
        index,
        index,
        Fragment([tr.doc.schema.node('paragraph')]),
      )) {
        return true;
      }
      if (trailingLines != null) {
        final removed = trailingLines.end - trailingLines.start;
        tr.replace(tr.selection.from - removed, tr.selection.from);
        tr.step(
          ReplaceStep(
            after - removed,
            after - removed,
            Slice(Fragment([tr.doc.schema.node('paragraph')]), 0, 0),
          ),
        );
        tr.setSelection(TextSelection(after - removed + 1));
        tr.setMeta('closeHistory', true);
      } else {
        _paragraphAfter(after, tr);
      }
    } else {
      final start = tr.selection.from;
      final prefix = pos.parent.textContent.substring(0, pos.parentOffset);
      final line = prefix.substring(prefix.lastIndexOf('\n') + 1);
      final indent = RegExp(r'^[ \t]*').stringMatch(line)!;
      final text = '\n$indent';
      tr.replace(
        start,
        tr.selection.to,
        Slice(Fragment([tr.doc.schema.node('text', text: text)]), 0, 0),
      );
      tr.setSelection(TextSelection(start + text.length));
    }
    return true;
  }

  void _horizontalRule(Transaction tr, Map<String, dynamic> args) {
    final node = tr.doc.schema.node(
      'horizontalRule',
      attrs: args.cast<String, Object?>(),
    );
    final pos = tr.doc.resolve(tr.selection.from), from = tr.selection.from;
    if (pos.parent.isTextblock && pos.parent.content.isEmpty) {
      tr.replace(pos.before(), pos.after(), Slice(Fragment([node]), 0, 0));
    } else {
      tr.replace(
        tr.selection.from,
        tr.selection.to,
        Slice(Fragment([node]), 0, 0),
      );
    }
    final after = tr.mapping.map(from, 1).clamp(0, tr.doc.content.size);
    final resolved = tr.doc.resolve(after);
    if (resolved.nodeAfter == null) {
      tr.replace(
        after,
        after,
        Slice(Fragment([tr.doc.schema.node('paragraph')]), 0, 0),
      );
    }
    tr.setSelection(Selection.near(tr.doc, after));
  }
}

extension on Node {
  String get firstItemType => type == 'taskList' ? 'taskItem' : 'listItem';
}

extension _JoinCommands on EditorCommands {
  void _clearNodes(Transaction tr) {
    while (_lift(tr)) {}
  }

  bool _paragraphIntoList(Transaction tr, {required bool join}) {
    final pos = tr.doc.resolve(tr.selection.from);
    if (!tr.selection.empty ||
        !pos.parent.isTextblock ||
        pos.parentOffset != 0 ||
        _ancestor(pos, _isItem) != null ||
        pos.depth < 1) {
      return false;
    }
    final boundary = tr.doc.resolve(pos.before()),
        previous = boundary.nodeBefore;
    if (previous == null || !_isList(previous.type)) return false;
    (Node, int)? lastItem(Node node, int start) {
      if (node.isLeaf) return null;
      for (var i = node.childCount - 1; i >= 0; i--) {
        final found = lastItem(
          node.child(i),
          start + node.content.positionAt(i) + 1,
        );
        if (found != null) return found;
      }
      return _isItem(node.type) ? (node, start) : null;
    }

    final last = lastItem(previous, boundary.pos - previous.nodeSize);
    if (last == null ||
        !last.$1.canReplace(
          last.$1.childCount,
          last.$1.childCount,
          Fragment([pos.parent]),
        )) {
      return false;
    }
    final target = last.$2 + last.$1.nodeSize - 1, block = pos.parent;
    tr.replace(pos.before(), pos.after());
    tr.replace(target, target, Slice(Fragment([block]), 0, 0));
    tr.setSelection(TextSelection(target + 1));
    if (join) _joinBoundary(tr, backward: true);
    return true;
  }

  bool _deleteAtItemEnd(Transaction tr) {
    final pos = tr.doc.resolve(tr.selection.from),
        depth = _ancestor(tr.doc.resolve(tr.selection.from), _isItem);
    if (depth == null || pos.pos + 1 != pos.end(depth)) return false;
    final cut = _cut(pos, false);
    if (cut == null ||
        !_isItem(cut.nodeBefore!.type) ||
        !_isItem(cut.nodeAfter!.type) ||
        !_canJoin(tr.doc, cut.pos)) {
      return false;
    }
    final step = ReplaceStep(cut.pos - 2, cut.pos + 2, Slice.empty);
    try {
      step.apply(tr.doc);
    } on ArgumentError {
      return false;
    }
    tr.step(step);
    return true;
  }

  bool _quoteBackspace(Transaction tr) {
    final pos = tr.doc.resolve(tr.selection.from);
    if (!tr.selection.empty || pos.parentOffset != 0 || pos.depth < 1) {
      return false;
    }
    final parent = pos.node(pos.depth - 1), index = pos.index(pos.depth - 1);
    if (index == 0) return false;
    if (parent.type == 'blockquote') return _lift(tr);
    final previous = parent.child(index - 1);
    if (previous.type != 'blockquote' || !previous.content.last.isTextblock) {
      return false;
    }
    final target = pos.before() - 2, content = pos.parent.content;
    tr.replace(target, pos.after(), Slice(content, 0, 0));
    tr.setSelection(TextSelection(target + content.size));
    return true;
  }

  ResolvedPos? _cut(ResolvedPos pos, bool backward) {
    for (var d = pos.depth - 1; d >= 0; d--) {
      if (backward
          ? pos.index(d) > 0
          : pos.index(d) + 1 < pos.node(d).childCount) {
        return pos.doc.resolve(backward ? pos.before(d + 1) : pos.after(d + 1));
      }
      if (_isCell(pos.node(d)) || pos.node(d).type == 'table') return null;
    }
    return null;
  }

  bool _textAt(Node node, bool end, {bool only = false}) {
    while (true) {
      if (node.isTextblock) return true;
      if (node.isLeaf ||
          node.content.isEmpty ||
          (only && node.childCount != 1)) {
        return false;
      }
      node = end ? node.content.last : node.content.first;
    }
  }

  bool _deleteBarrier(Transaction tr, ResolvedPos cut) {
    final before = cut.nodeBefore!, after = cut.nodeAfter!, index = cut.index();
    final schema = tr.doc.schema;
    if (!before.isOpaque &&
        !after.isOpaque &&
        schema.compatibleContent(before.type, after.type)) {
      if (before.content.isEmpty && cut.parent.canReplace(index - 1, index)) {
        tr.replace(cut.pos - before.nodeSize, cut.pos);
        return true;
      }
      if (cut.parent.canReplace(index, index + 1) &&
          (after.isTextblock || _canJoin(tr.doc, cut.pos))) {
        // A code textblock accepts text but drops incompatible inline marks.
        if (before.type == 'codeBlock' && after.isTextblock) {
          final content = before.content.append(
            Fragment(
              after.content.map(
                (n) => n.type == 'hardBreak'
                    ? schema.node('text', text: '\n')
                    : n.withMarks(const []),
              ),
            ),
          );
          tr.replace(
            cut.pos - before.nodeSize,
            cut.pos + after.nodeSize,
            Slice(Fragment([before.copy(content)]), 0, 0),
          );
          tr.setSelection(TextSelection(cut.pos - 1));
        } else {
          _joinAt(tr, cut.pos);
        }
        return true;
      }
    }
    final canDeleteAfter = cut.parent.canReplace(index, index + 1);
    if (!before.isLeaf && !after.isOpaque && canDeleteAfter) {
      final match = before.contentMatchAt(before.childCount),
          wrapping = before
              .contentMatchAt(before.childCount)
              .findWrapping(after.type);
      if (wrapping != null &&
          match
              .matchType(wrapping.isEmpty ? after.type : wrapping.first)!
              .validEnd) {
        var wrap = Fragment.empty;
        for (final type in wrapping.reversed) {
          wrap = Fragment([schema.node(type, content: wrap)]);
        }
        wrap = Fragment([before.copy(wrap)]);
        final end = cut.pos + after.nodeSize;
        tr.step(
          ReplaceAroundStep(
            cut.pos - 1,
            end,
            cut.pos,
            end,
            Slice(wrap, 1, 0),
            wrapping.length,
          ),
        );
        final joinAt = end + 2 * wrapping.length;
        if (joinAt <= tr.doc.content.size &&
            tr.doc.resolve(joinAt).nodeAfter?.type == before.type &&
            _canJoin(tr.doc, joinAt)) {
          _joinAt(tr, joinAt);
        }
        return true;
      }
    }
    if (!after.isOpaque) {
      final selection = Selection.near(tr.doc, cut.pos);
      final range = _blockRange(tr.doc, selection),
          target = range == null ? null : _liftTarget(range);
      if (target != null && target >= cut.depth) {
        _liftRange(tr, range!, target);
        return true;
      }
    }
    if (canDeleteAfter &&
        _textAt(after, false, only: true) &&
        _textAt(before, true)) {
      var at = before, afterText = after, afterDepth = 1;
      final wrap = <Node>[];
      while (true) {
        wrap.add(at);
        if (at.isTextblock) break;
        at = at.content.last;
      }
      while (!afterText.isTextblock) {
        afterText = afterText.content.first;
        afterDepth++;
      }
      if (at.canReplace(at.childCount, at.childCount, afterText.content)) {
        var end = Fragment.empty;
        for (final node in wrap.reversed) {
          end = Fragment([node.copy(end)]);
        }
        tr.step(
          ReplaceAroundStep(
            cut.pos - wrap.length,
            cut.pos + after.nodeSize,
            cut.pos + afterDepth,
            cut.pos + after.nodeSize - afterDepth,
            Slice(end, wrap.length, 0),
            0,
          ),
        );
        return true;
      }
    }
    return false;
  }

  bool _joinBoundary(
    Transaction tr, {
    required bool backward,
    bool selectOnly = false,
  }) {
    if (!tr.selection.empty) return false;
    final pos = tr.doc.resolve(tr.selection.head);
    if (!pos.parent.isTextblock ||
        (backward
            ? pos.parentOffset != 0
            : pos.parentOffset != pos.parent.content.size)) {
      return false;
    }
    final cut = _cut(pos, backward);
    if (cut == null) {
      if (backward && !selectOnly) return _lift(tr);
      return false;
    }
    final other = backward ? cut.nodeBefore! : cut.nodeAfter!;
    if (selectOnly) {
      tr.setSelection(
        NodeSelection(tr.doc, backward ? cut.pos - other.nodeSize : cut.pos),
      );
      return true;
    }
    if (_mediaTypes.contains(other.type)) {
      tr.setSelection(
        NodeSelection(tr.doc, backward ? cut.pos - other.nodeSize : cut.pos),
      );
      return true;
    }
    if (other.type == 'horizontalRule') {
      final at = backward ? cut.pos - other.nodeSize : cut.pos;
      tr.replace(at, at + other.nodeSize);
      return true;
    }
    if (!other.isOpaque && other.type != 'table' && _deleteBarrier(tr, cut)) {
      return true;
    }
    if (pos.parent.content.isEmpty &&
        (_textAt(other, backward) || other.isLeaf)) {
      for (var d = pos.depth; d > 0; d--) {
        final step = replaceStep(tr.doc, pos.before(d), pos.after(d));
        if (step is ReplaceStep && step.slice.size < step.to - step.from) {
          tr.step(step);
          final mapped = tr.mapping.map(cut.pos, backward ? -1 : 1);
          tr.setSelection(
            _textAt(other, backward)
                ? Selection.near(tr.doc, mapped, bias: backward ? -1 : 1)
                : NodeSelection(
                    tr.doc,
                    backward ? cut.pos - other.nodeSize : mapped,
                  ),
          );
          return true;
        }
        if (d == 1 || pos.node(d - 1).childCount > 1) break;
      }
    }
    if (other.type == 'table') {
      tr.setSelection(
        NodeSelection(tr.doc, backward ? cut.pos - other.nodeSize : cut.pos),
      );
      return true;
    }
    if (other.isAtom && cut.depth == pos.depth - 1) {
      tr.replace(
        backward ? cut.pos - other.nodeSize : cut.pos,
        backward ? cut.pos : cut.pos + other.nodeSize,
      );
      return true;
    }
    // Non-atom opaque blocks stay selectable.
    if (other.isOpaque && !other.isAtom) {
      tr.setSelection(
        NodeSelection(tr.doc, backward ? cut.pos - other.nodeSize : cut.pos),
      );
      return true;
    }
    return false;
  }
}
