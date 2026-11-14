part of '../model.dart';

final _headingRule = RegExp(r'^(#{1,6}|＃{1,6})\s$');
final _ruleWhitespace = RegExp(r'\s');
final _ruleWord = RegExp(r'[A-Za-z0-9_]');
final _codeFenceRule = RegExp(r'^(?:```|~~~|···)[a-z]*$');
final _orderedListRule = RegExp(r'^([0-9０-９]+)[．.]\s$');
final _taskListRule = RegExp(r'^\s*(\[([( |x])?\])\s$');
final _backtickCodeRule = RegExp(r'^```([a-z]+)?[\s\n]$');
final _tildeCodeRule = RegExp(r'^~~~([a-z]+)?[\s\n]$');
final _middleDotCodeRule = RegExp(r'^···([a-z]+)?[\s\n]$');
final _horizontalRulePattern = RegExp(r'^(?:---|—-|___\s|\*\*\*\s)$');
final _wideHorizontalRule = RegExp(r'^(?:—{3,}|－{3,})$');
final _bulletListRule = RegExp(r'^\s*([-+*])\s$');
final _wideBulletListRule = RegExp(r'^\s*[－＊·•]\s$');
final _wideTaskListRule = RegExp(r'^\s*(?:【\s?】|「」)\s$');
final _blockquoteRule = RegExp(r'^\s*>\s$');
final _wideBlockquoteRule = RegExp(r'^\s*[》＞]\s$');
final _inlineMarkRules = [
  for (final (delimiter, name, relaxed) in <(String, String, bool)>[
    ('**', 'bold', true),
    ('__', 'bold', false),
    ('~~', 'strike', true),
    ('==', 'highlight', true),
    ('*', 'italic', true),
    ('_', 'italic', false),
    ('`', 'code', false),
  ])
    (
      delimiter,
      name,
      relaxed,
      RegExp(
        '${RegExp.escape(delimiter)}([^${RegExp.escape(delimiter[0])}\\n]+?)${RegExp.escape(delimiter)}\$',
      ),
    ),
];

extension _InputRulesHelpers on EditorCommands {
  void _insertText(
    EditorState state,
    Transaction tr,
    String text, {
    required bool committed,
    Object? composition,
  }) {
    if (text.isEmpty && state.selection.empty) return;
    if (text.isNotEmpty && _leaveSelectedAtom(state, tr)) {
      _insertText(
        EditorState(doc: tr.doc, selection: tr.selection),
        tr,
        text,
        committed: committed,
        composition: composition,
      );
      return;
    }
    final schema = tr.doc.schema;
    final marks =
        tr.doc.resolve(state.selection.from).parent.type == 'codeBlock'
        ? const <Mark>[]
        : state.storedMarks ?? tr.doc.resolve(state.selection.from).marks;
    tr
        .replace(
          state.selection.from,
          state.selection.to,
          Slice(
            text.isEmpty
                ? Fragment.empty
                : Fragment([schema.node('text', text: text, marks: marks)]),
            0,
            0,
          ),
        )
        .setSelection(
          TextSelection(
            state.selection.from +
                text.length +
                (state.doc.resolve(state.selection.from).depth == 0 ? 1 : 0),
          ),
        );
    if (state.storedMarks != null) tr.setStoredMarks(marks);
    if (composition != null) tr.setMeta('composition', composition);
    if (committed) {
      final insertedFrom = tr.selection.head - text.length;
      final insertedTo = tr.selection.head;
      final mapFrom = tr.mapping.maps.length;
      _inputRules(tr);
      final mapping = Mapping(tr.mapping.maps.skip(mapFrom));
      final from = mapping.map(insertedFrom, 1);
      final to = mapping.map(insertedTo, -1);
      if (from < to) _autolink(tr, insertedRange: (from: from, to: to));
    }
  }

  // Text the composition inserted that still exists, in document order.
  List<({int from, int to})> _composedRanges(
    EditorState state,
    Object? composition,
  ) {
    final event = state.history._done.lastOrNull;
    if (composition == null || event?.composition != composition) return [];
    // A typing burst can join the same history event; only recent edits matter.
    final maps = event!.mapping.maps;
    var ranges = <({int from, int to})>[];
    for (final map in maps.skip(math.max(0, maps.length - 256))) {
      ranges = [
        for (final range in ranges)
          if (map.map(range.from, 1) case final from
              when from < map.map(range.to, -1))
            (from: from, to: map.map(range.to, -1)),
      ];
      if (map._ranges == null && map.newSize > 0) {
        ranges.add((from: map.from, to: map.from + map.newSize));
      }
    }
    final size = state.doc.content.size;
    return [
      for (final range in ranges)
        if (range.to <= size) range,
    ];
  }

  void _inputRules(Transaction tr) {
    final cursor = tr.doc.resolve(tr.selection.head);
    if (!cursor.parent.isTextblock) return;
    final block = cursor.parent;
    if (block.type == 'codeBlock') return;
    if (cursor.marks.any((m) => m.type == 'code')) return;
    final windowStart = math.max(0, cursor.parentOffset - 500);
    final text = block.content
        .cut(windowStart, cursor.parentOffset)
        .inlineText();
    var heading = windowStart == 0 ? _headingRule.firstMatch(text) : null;
    if (heading != null &&
        !cursor
            .node(cursor.depth - 1)
            .canReplace(
              cursor.index(cursor.depth - 1),
              cursor.index(cursor.depth - 1) + 1,
              Fragment([tr.doc.schema.node('heading')]),
            )) {
      heading = null;
    }
    final typedDoc = tr.doc, typedSelection = tr.selection;
    final mapFrom = tr.mapping.maps.length;
    if (_structuralRule(tr, cursor, text, windowStart)) {
      // The structural helper fitted the wrapper or changed the textblock.
    } else if (heading != null) {
      final start = cursor.start();
      tr.step(ReplaceStep(start, tr.selection.head, Slice.empty));
      final current = tr.doc.resolve(start).parent;
      tr.step(
        _SetNodeStep(
          start - 1,
          tr.doc.schema.node(
            'heading',
            attrs: {'level': heading[1]!.length},
            content: current.content,
          ),
        ),
      );
      tr.setSelection(TextSelection(start));
    } else {
      var matched = false;
      for (final (delimiter, name, relaxed, pattern) in _inlineMarkRules) {
        final ch = delimiter[0];
        final match = pattern.firstMatch(text);
        if (match == null) continue;
        final inner = match[1]!;
        final before = match.start == 0 ? '' : text[match.start - 1];
        final boundary = before.isEmpty || _ruleWhitespace.hasMatch(before);
        final allowed = name == 'code'
            ? before != '`'
            : (relaxed &&
                      inner.trim() == inner &&
                      (before.isEmpty ||
                          (before != ch && !_ruleWord.hasMatch(before)))) ||
                  (boundary && inner.trim().isNotEmpty);
        if (!allowed) continue;
        final start = cursor.start() + windowStart + match.start;
        final end = tr.selection.head;
        final innerNodes = block.content.cut(
          start - cursor.start() + delimiter.length,
          end - cursor.start() - delimiter.length,
        );
        if (innerNodes.any(
          (n) => n.marks.any(
            (m) =>
                m.type != name &&
                (tr.doc.schema.marks[m.type]?.excludes.contains('*') == true ||
                    tr.doc.schema.marks[m.type]?.excludes.contains(name) ==
                        true),
          ),
        )) {
          continue;
        }
        final originalMarks =
            tr.doc.resolve(start).nodeAfter?.marks ?? const <Mark>[];
        tr.step(ReplaceStep(end - delimiter.length, end, Slice.empty));
        tr.step(ReplaceStep(start, start + delimiter.length, Slice.empty));
        tr.step(
          AddMarkStep(start, start + inner.length, tr.doc.schema.mark(name)),
        );
        tr.setSelection(TextSelection(start + inner.length));
        tr.setStoredMarks(originalMarks);
        matched = true;
        break;
      }
      if (!matched) return;
    }
    tr._inputRuleUndo = _InputRuleUndo(
      typedDoc,
      typedSelection,
      cursor.blockIndex,
      Mapping(tr.mapping.maps.skip(mapFrom)),
    );
    tr.setMeta('inputRule', true);
  }

  void _undoInputRule(EditorState state, Transaction tr) {
    final rule = state._inputRule;
    if (rule == null) return;
    tr
        .step(
          _DocumentStep(
            rule.typed,
            BlockRange(
              rule.blockIndex,
              rule.blockIndex + 1,
              rule.blockIndex + 1,
            ),
          ),
        )
        .setSelection(rule.selection)
        .setMeta('inputRule', true);
    tr.mapping = rule.mapping.invert();
  }
}

extension _StructuralInputRules on EditorCommands {
  // Enter never reaches the text input rules, so a fence typed alone on its
  // line becomes a code block here, like the typed-space form.
  bool _codeFenceEnter(Transaction tr) {
    final selection = tr.selection;
    if (selection is! TextSelection || !selection.empty) return false;
    final cursor = tr.doc.resolve(selection.head);
    final block = cursor.parent;
    if (block.type != 'paragraph' ||
        cursor.parentOffset != block.content.size) {
      return false;
    }
    final text = block.textContent;
    if (!_codeFenceRule.hasMatch(text)) return false;
    return _structuralRule(tr, cursor, '$text\n', 0);
  }

  bool _structuralRule(
    Transaction tr,
    ResolvedPos cursor,
    String text,
    int windowStart,
  ) {
    if (windowStart != 0) return false;
    String? type;
    Map<String, Object?>? attrs;
    final ordered = _orderedListRule.firstMatch(text);
    final task = _taskListRule.firstMatch(text);
    final code =
        _backtickCodeRule.firstMatch(text) ??
        _tildeCodeRule.firstMatch(text) ??
        _middleDotCodeRule.firstMatch(text);
    final hr =
        _horizontalRulePattern.hasMatch(text) ||
        _wideHorizontalRule.hasMatch(text);
    if (_bulletListRule.hasMatch(text) || _wideBulletListRule.hasMatch(text)) {
      type = 'bulletList';
    } else if (ordered != null) {
      type = 'orderedList';
      final digits = ordered[1]!.runes.map(
        (r) => r >= 0xff10 && r <= 0xff19 ? r - 0xfee0 : r,
      );
      attrs = {'start': int.parse(String.fromCharCodes(digits))};
    } else if (task != null || _wideTaskListRule.hasMatch(text)) {
      type = 'taskItem';
      attrs = {'checked': task?[2] == 'x'};
    } else if (_blockquoteRule.hasMatch(text) ||
        _wideBlockquoteRule.hasMatch(text)) {
      type = 'blockquote';
    } else if (code != null) {
      type = 'codeBlock';
      attrs = {'language': code[1]};
    } else if (!hr) {
      return false;
    }
    final start = cursor.start();
    if (hr) {
      tr.replace(start, tr.selection.head);
      tr.setSelection(TextSelection(start));
      // The rule replaces the empty paragraph with the atom and adds no
      // trailing paragraph.
      tr.replace(
        start - 1,
        start - 1,
        Slice(Fragment([tr.doc.schema.node('horizontalRule')]), 0, 0),
      );
      tr.setSelection(Selection.near(tr.doc, tr.mapping.maps.last.map(start)));
      return true;
    }
    // textblock rules cannot replace the required first paragraph of an item.
    if (type == 'codeBlock') {
      final parent = cursor.node(cursor.depth - 1),
          i = cursor.index(cursor.depth - 1);
      if (!parent.canReplace(i, i + 1, Fragment([tr.doc.schema.node(type!)]))) {
        return false;
      }
    } else {
      final range = _blockRange(tr.doc, tr.selection);
      if (range == null || _findWrapping(range, type!, attrs) == null) {
        return false;
      }
    }
    tr.replace(start, tr.selection.head);
    tr.setSelection(TextSelection(start));
    if (type == 'codeBlock') {
      _setBlock(
        EditorState(doc: tr.doc, selection: tr.selection),
        tr,
        type,
        attrs!,
      );
    } else {
      _wrap(tr, type, attrs);
      final boundary = start - 1;
      final before = tr.doc.resolve(boundary).nodeBefore;
      if (before?.type == type &&
          _canJoin(tr.doc, boundary) &&
          (type != 'orderedList' ||
              before!.childCount + (before.attrs['start'] as int) ==
                  attrs!['start'])) {
        _joinAt(tr, boundary);
      }
    }
    return true;
  }
}

extension _InputRulesDispatch on EditorCommands {
  void _commitComposition(
    EditorState state,
    Transaction tr,
    Map<String, dynamic> args,
  ) {
    tr.setMeta('composition', args['composition']);
    final mapFrom = tr.mapping.maps.length;
    _inputRules(tr);
    final mapping = Mapping(tr.mapping.maps.skip(mapFrom));
    final ranges =
        [
            for (final range in _composedRanges(state, args['composition']))
              (from: mapping.map(range.from, 1), to: mapping.map(range.to, -1)),
          ].where((range) => range.from < range.to).toList()
          ..sort((a, b) => b.to.compareTo(a.to));
    for (final range in ranges) {
      _unlinkTrailingWhitespace(tr, range);
    }
    _autolink(tr);
  }
}
