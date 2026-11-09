part of '../model.dart';

/// Builds transactions for named editing, formatting and structural commands.
class EditorCommands {
  const EditorCommands({this.trailingParagraph = false});
  final bool trailingParagraph;

  Transaction execute(
    EditorState state,
    String name, [
    Map<String, dynamic> args = const {},
  ]) {
    final tr = state.tr;
    if (_tableCommand(tr, name, args)) {
      if (tr.docChanged) {
        final context = tableContext(tr.doc, tr.selection.head);
        if (context != null) {
          final fixed = fixTables(context.table);
          if (!identical(fixed, context.table)) {
            final selection = tr.selection;
            tr.step(_SetNodeStep(context.tablePosition, fixed));
            tr.setSelection(selection);
          }
        }
      }
      return tr;
    }
    switch (name) {
      case 'insertAtomBlock':
        _insertAtom(
          tr,
          tr.doc.schema.node(
            args['type'] as String,
            attrs: (args['attrs'] as Map?)?.cast<String, Object?>(),
          ),
        );
      case 'setMediaWidth':
      case 'setMediaName':
        final selection = tr.selection;
        if (selection is NodeSelection) {
          final node = tr.doc.nodeAt(selection.from)!;
          if (name == 'setMediaWidth' &&
              {'image', 'video'}.contains(node.type)) {
            final raw = args['percent'];
            final percent = raw == null
                ? null
                : clampWidthPercent(
                    raw is num ? raw : num.tryParse(raw.toString()),
                  );
            if (raw == null || percent != null) {
              tr.step(AttrStep(selection.from, 'widthPercent', percent));
            }
          } else if (name == 'setMediaName' &&
              _mediaTypes.contains(node.type)) {
            final value = (args['name'] as String? ?? '').trim();
            tr.step(
              AttrStep(selection.from, 'name', value.isEmpty ? null : value),
            );
          }
        }
      case 'deleteBlock':
        if (tr.selection is NodeSelection) {
          _delete(state, tr, backward: true, word: false);
        }
      case 'moveBlockUp':
      case 'moveBlockDown':
        _moveBlock(tr, name == 'moveBlockUp' ? -1 : 1);
      case 'caretAfterNode':
        _caretAfterSelectedNode(tr);
      case 'setLink':
      case 'unsetLink':
      case 'toggleLink':
        _editLink(tr, name, args);
      case 'insertReference':
        _insertReference(tr, args);
      case 'pasteText':
        _pasteText(tr, args['text'] as String, plain: args['plain'] == true);
      case 'pasteSlice':
        final slice = args['slice'] as Slice, to = tr.selection.to;
        _replacePasteRange(tr, tr.selection.from, to, slice);
        tr.setSelection(Selection.near(tr.doc, tr.mapping.map(to, 1)));
      case 'insertText':
        _insertText(
          state,
          tr,
          args['text'] as String,
          committed: args['committed'] != false,
          composition: args['composition'],
        );
      case 'commitComposition':
        tr.setMeta('composition', args['composition']);
        _inputRules(tr);
        _autolink(tr);
      case 'deleteBackward':
        if (state._inputRule != null) {
          _undoInputRule(state, tr);
        } else {
          _delete(state, tr, backward: true, word: args['word'] == true);
        }
      case 'deleteForward':
        _delete(state, tr, backward: false, word: args['word'] == true);
      case 'splitBlock':
        if (!_codeFenceEnter(tr) && !_codeEnter(tr) && !_splitItem(tr)) {
          _split(state, tr);
        }
      case 'splitListItem':
        _splitItem(tr);
      case 'toggleBulletList':
      case 'toggleOrderedList':
      case 'toggleTaskList':
        _toggleList(tr, switch (name) {
          'toggleOrderedList' => 'orderedList',
          'toggleTaskList' => 'taskList',
          _ => 'bulletList',
        });
      case 'wrapInList':
        _wrap(
          tr,
          args['type'] as String? ?? 'bulletList',
          (args['attrs'] as Map?)?.cast<String, Object?>(),
          list: true,
        );
      case 'sinkListItem':
        _sink(tr);
      case 'liftListItem':
        _lift(tr, list: true);
      case 'lift':
        _lift(tr);
      case 'wrapIn':
        _wrap(
          tr,
          args['type'] as String? ?? 'blockquote',
          (args['attrs'] as Map?)?.cast<String, Object?>(),
        );
      case 'toggleBlockquote':
        final depth = _ancestor(
          tr.doc.resolve(tr.selection.from),
          (type) => type == 'blockquote',
        );
        if (depth == null) {
          _wrap(tr, 'blockquote', null);
        } else {
          _lift(tr);
        }
      case 'setCodeBlock':
      case 'toggleCodeBlock':
        _setBlock(
          state,
          tr,
          name == 'toggleCodeBlock' &&
                  tr.doc.resolve(tr.selection.from).parent.type == 'codeBlock'
              ? 'paragraph'
              : 'codeBlock',
          args.cast<String, Object?>(),
        );
      case 'setHorizontalRule':
        _horizontalRule(tr, args);
      case 'toggleTaskItem':
        final pos = tr.doc.resolve(tr.selection.from),
            depth = _ancestor(
              tr.doc.resolve(tr.selection.from),
              (t) => t == 'taskItem',
            );
        if (depth != null) {
          tr.step(
            AttrStep(
              pos.before(depth),
              'checked',
              args['checked'] ?? pos.node(depth).attrs['checked'] != true,
            ),
          );
        }
      case 'joinBackward':
        _joinBoundary(tr, backward: true);
      case 'joinForward':
        _joinBoundary(tr, backward: false);
      case 'selectNodeBackward':
        _joinBoundary(tr, backward: true, selectOnly: true);
      case 'exitCode':
        _codeEnter(tr, exit: true);
      case 'arrowDown':
        final pos = tr.doc.resolve(tr.selection.head);
        if (tr.selection.empty &&
            pos.parent.type == 'codeBlock' &&
            pos.parentOffset == pos.parent.content.size) {
          if (tr.doc.nodeAt(pos.after()) != null) {
            tr.setSelection(Selection.near(tr.doc, pos.after()));
          } else {
            _codeEnter(tr, exit: true);
          }
        }
      case 'tab':
        if (!_codeIndent(tr, outdent: false) &&
            !_paragraphIntoList(tr, join: false)) {
          _sink(tr);
        }
      case 'shiftTab':
        if (!_codeIndent(tr, outdent: true)) _lift(tr, list: true);
      case 'hardBreak':
        if (_codeEnter(tr)) break;
        if (_leaveSelectedAtom(state, tr)) break;
        final marks =
            (state.storedMarks ?? state.doc.resolve(state.selection.from).marks)
                .where(
                  (m) => state.doc.schema.marks[m.type]?.keepOnSplit != false,
                )
                .toList();
        tr
            .step(
              ReplaceStep(
                state.selection.from,
                state.selection.to,
                Slice(Fragment([state.doc.schema.node('hardBreak')]), 0, 0),
              ),
            )
            .setSelection(TextSelection(state.selection.from + 1))
            .setStoredMarks(marks);
      case 'toggleMark':
        _toggleMark(
          state,
          tr,
          args['type'] as String,
          (args['attrs'] as Map?)?.cast<String, Object?>(),
        );
      case 'setHeading':
      case 'toggleHeading':
        final level = args['level'] as int? ?? 1;
        if (level < 1 || level > 6) throw ArgumentError.value(level, 'level');
        final active = state.doc.resolve(state.selection.from).parent;
        _setBlock(
          state,
          tr,
          name == 'toggleHeading' &&
                  active.type == 'heading' &&
                  active.attrs['level'] == level
              ? 'paragraph'
              : 'heading',
          {'level': level},
        );
      case 'setParagraph':
        _setBlock(state, tr, 'paragraph', const {});
      case 'clearFormatting':
        if (state.selection.empty) {
          tr.setStoredMarks(const []);
        } else {
          final marks = <Mark>{};
          _visitSelected(state, (n) => marks.addAll(n.marks));
          for (final mark in marks) {
            tr.step(
              RemoveMarkStep(state.selection.from, state.selection.to, mark),
            );
          }
        }
        _clearNodes(tr);
        _setBlock(
          EditorState(doc: tr.doc, selection: tr.selection),
          tr,
          'paragraph',
          const {},
          clear: false,
        );
      case 'selectAll':
        tr.setSelection(AllSelection(tr.doc));
      case 'deleteBefore':
        _deleteBefore(tr, args['position'] as int);
      case 'setTextSelection':
        tr.setSelection(
          TextSelection(args['anchor'] as int, args['head'] as int?),
        );
      case 'setNodeSelection':
        tr.setSelection(NodeSelection(tr.doc, args['position'] as int));
      case 'undo':
        _history(state, tr, false);
      case 'redo':
        _history(state, tr, true);
      case 'undoInputRule':
        _undoInputRule(state, tr);
      default:
        throw ArgumentError.value(name, 'name', 'Unknown editor command');
    }
    if (name == 'splitBlock' && tr.docChanged) _autolinkBeforeSplit(tr);
    if (name == 'pasteText' || name == 'pasteSlice') {
      tr.setMeta('closeHistory', true);
    }
    if (trailingParagraph &&
        tr.docChanged &&
        tr.metadata['inputRule'] != true &&
        tr.metadata['history'] != true &&
        tr.doc.blocks.last.type != 'paragraph') {
      final end = tr.doc.content.size;
      tr.step(
        ReplaceStep(
          end,
          end,
          Slice(Fragment([tr.doc.schema.node('paragraph')]), 0, 0),
        ),
      );
    }
    return tr;
  }

  bool _leaveSelectedAtom(EditorState state, Transaction tr) {
    final selection = state.selection;
    if (selection is GapSelection) {
      _paragraphAfter(selection.head, tr);
      return true;
    }
    if (selection is! NodeSelection) return false;
    final block = tr.doc.nodeAt(selection.from)!;
    if (!block.isAtom) return false;
    _paragraphAfter(selection.to, tr);
    return true;
  }

  void _paragraphAfter(int position, Transaction tr) {
    final next = tr.doc.resolve(position).nodeAfter;
    if (next == null || next.type != 'paragraph' || next.content.isNotEmpty) {
      tr.step(
        ReplaceStep(
          position,
          position,
          Slice(Fragment([tr.doc.schema.node('paragraph')]), 0, 0),
        ),
      );
    }
    tr.setSelection(TextSelection(position + 1));
  }

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
      _inputRules(tr);
      _autolink(tr);
    }
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
        .map((n) => n.isText ? n.text : '\ufffc')
        .join();
    var heading = windowStart == 0
        ? RegExp(r'^(#{1,6}|＃{1,6})\s$').firstMatch(text)
        : null;
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
      final patterns = <(String, String, bool)>[
        ('**', 'bold', true),
        ('__', 'bold', false),
        ('~~', 'strike', true),
        ('==', 'highlight', true),
        ('*', 'italic', true),
        ('_', 'italic', false),
        ('`', 'code', false),
      ];
      var matched = false;
      for (final (delimiter, name, relaxed) in patterns) {
        final ch = delimiter[0];
        final pattern = RegExp(
          '${RegExp.escape(delimiter)}([^${RegExp.escape(ch)}\\n]+?)${RegExp.escape(delimiter)}\$',
        );
        final match = pattern.firstMatch(text);
        if (match == null) continue;
        final inner = match[1]!;
        final before = match.start == 0 ? '' : text[match.start - 1];
        final boundary = before.isEmpty || RegExp(r'\s').hasMatch(before);
        final allowed = name == 'code'
            ? before != '`'
            : (relaxed &&
                      inner.trim() == inner &&
                      (before.isEmpty ||
                          (before != ch &&
                              !RegExp(r'[A-Za-z0-9_]').hasMatch(before)))) ||
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

  void _toggleMark(
    EditorState state,
    Transaction tr,
    String type,
    Map<String, Object?>? attrs,
  ) {
    if (tr.doc.resolve(state.selection.from).parent.type == 'codeBlock') return;
    final mark = tr.doc.schema.mark(type, attrs);
    if (state.selection.empty) {
      final marks =
          state.storedMarks ?? state.doc.resolve(state.selection.head).marks;
      tr.setStoredMarks(
        marks.any((m) => m.type == type)
            ? marks.where((m) => m.type != type).toList()
            : tr.doc.schema.addMark(marks, mark),
      );
    } else {
      final active = state.toolbar.activeMarks.contains(type);
      final existing = <Mark>{};
      _visitSelected(state, (node) {
        for (final m in node.marks) {
          if (m.type == type) {
            existing.add(m);
          }
        }
      });
      if (active) {
        for (final m in existing) {
          tr.step(RemoveMarkStep(state.selection.from, state.selection.to, m));
        }
      } else {
        tr.step(AddMarkStep(state.selection.from, state.selection.to, mark));
      }
    }
  }

  void _visitSelected(EditorState state, void Function(Node) visit) {
    final from = state.selection.from, to = state.selection.to;
    void walk(Node node, int start) {
      if (node.isOpaque || node.isLeaf) return;
      final a = (from - start).clamp(0, node.content.size),
          b = (to - start).clamp(a, node.content.size);
      if (a == b) return;
      final first = node.content.indexAt(a), last = node.content.indexAt(b - 1);
      for (var i = first; i <= last; i++) {
        final child = node.child(i), pos = start + node.content.positionAt(i);
        if (child.isText || child.marks.isNotEmpty) visit(child);
        walk(child, pos + 1);
      }
    }

    walk(state.doc, 0);
  }

  void _setBlock(
    EditorState state,
    Transaction tr,
    String type,
    Map<String, Object?> attrs, {
    bool clear = true,
  }) {
    final positions = <int>[];
    void walk(Node node, int start) {
      if (node.isTextblock) {
        positions.add(start - 1);
        return;
      }
      if (node.isLeaf) return;
      final a = (state.selection.from - start).clamp(0, node.content.size);
      final b = (state.selection.to - start).clamp(a, node.content.size);
      final first = node.content.indexAt(a),
          last = node.content.indexAt(b > a ? b - 1 : b);
      for (var i = first; i <= last && i < node.childCount; i++) {
        walk(node.child(i), start + node.content.positionAt(i) + 1);
      }
    }

    walk(tr.doc, 0);
    final canChange = positions.any((position) {
      final block = tr.doc.nodeAt(position)!, parent = tr.doc.resolve(position);
      return (block.type != type ||
              attrs.entries.any((e) => block.attrs[e.key] != e.value)) &&
          parent.parent.canReplace(
            parent.index(),
            parent.index() + 1,
            Fragment([tr.doc.schema.node(type)]),
          );
    });
    if (clear && !canChange) {
      _clearNodes(tr);
      _setBlock(
        EditorState(doc: tr.doc, selection: tr.selection),
        tr,
        type,
        attrs,
        clear: false,
      );
      return;
    }
    for (final position in positions) {
      final block = tr.doc.nodeAt(position)!, parent = tr.doc.resolve(position);
      final values = {...block.attrs}
        ..remove('level')
        ..remove('language');
      values.addAll(attrs);
      if (type != 'heading') values.remove('level');
      if (type != 'codeBlock') values.remove('language');
      var content = block.content;
      if (type == 'codeBlock') {
        content = Fragment(
          content.map(
            (n) => n.type == 'hardBreak'
                ? tr.doc.schema.node('text', text: '\n')
                : n.withMarks(const []),
          ),
        );
      }
      final next = tr.doc.schema.node(type, attrs: values, content: content);
      if (!parent.parent.canReplace(
        parent.index(),
        parent.index() + 1,
        Fragment([next]),
      )) {
        continue;
      }
      tr.step(_SetNodeStep(position, next));
    }
  }

  void _split(EditorState state, Transaction tr) {
    if (_leaveSelectedAtom(state, tr)) return;
    if (state.selection is NodeSelection) {
      _paragraphAfter(state.selection.to, tr);
      return;
    }
    if (!state.selection.empty) {
      tr
          .step(
            ReplaceStep(state.selection.from, state.selection.to, Slice.empty),
          )
          .setSelection(TextSelection(state.selection.from));
    }
    final pos = tr.doc.resolve(tr.selection.head);
    if (!pos.parent.isTextblock) return;
    final block = pos.parent;
    if (block.content.isEmpty && _lift(tr)) return;
    final nextType =
        block.type == 'heading' && pos.parentOffset == block.content.size
        ? 'paragraph'
        : block.type;
    final first = block.copy(Fragment.empty);
    final second = tr.doc.schema.node(
      nextType,
      attrs: nextType == block.type ? block.attrs : const {},
    );
    tr
        .step(
          ReplaceStep(
            tr.selection.head,
            tr.selection.head,
            Slice(Fragment([first, second]), 1, 1),
          ),
        )
        .setSelection(TextSelection(pos.pos + 2));
    if (pos.parentOffset == 0 &&
        block.content.isNotEmpty &&
        block.type != 'paragraph') {
      tr.step(_SetNodeStep(pos.before(), tr.doc.schema.node('paragraph')));
    }
    final marks =
        state.storedMarks ??
        (state.doc.resolve(state.selection.to).parentOffset > 0
            ? state.doc.resolve(state.selection.from).marks
            : const <Mark>[]);
    tr.setStoredMarks(
      marks
          .where((m) => tr.doc.schema.marks[m.type]?.keepOnSplit != false)
          .toList(),
    );
  }

  // Clears what precedes [position] within its code block, table cell or the
  // document. The block holding it keeps its type and attributes.
  void _deleteBefore(Transaction tr, int position) {
    final pos = tr.doc.resolve(position);
    var floor = pos.parent.type == 'codeBlock' ? pos.depth : 0;
    for (var d = pos.depth; d > 0 && floor == 0; d--) {
      if (_isCell(pos.node(d))) floor = d;
    }
    var head = pos.start();
    tr.replace(head, position);
    // Deepest first, so the outer positions stay valid.
    for (var d = pos.depth; d > floor; d--) {
      final from = pos.start(d - 1), to = pos.before(d);
      if (from == to) continue;
      final parent = pos.node(d - 1);
      if (_isItem(parent.type)) {
        // An item must open with a paragraph, so only its text goes.
        final opening = parent.child(0);
        tr.replace(from + opening.nodeSize, to);
        head -= to - from - opening.nodeSize;
        tr.replace(from + 1, from + 1 + opening.content.size);
        head -= opening.content.size;
        continue;
      }
      tr.replace(from, to);
      head -= to - from;
    }
    tr.setSelection(Selection.near(tr.doc, head)).setMeta('closeHistory', true);
  }

  void _delete(
    EditorState state,
    Transaction tr, {
    required bool backward,
    required bool word,
  }) {
    final selection = state.selection;
    if (selection is GapSelection) {
      final pos = tr.doc.resolve(selection.head);
      final other = backward ? pos.nodeBefore : pos.nodeAfter;
      if (other == null || !other.isAtom) return;
      final at = backward ? selection.head - other.nodeSize : selection.head;
      if (other.type == 'horizontalRule') {
        tr.replace(at, at + other.nodeSize);
        tr.setSelection(
          Selection.beside(
            tr.doc,
            at.clamp(0, tr.doc.content.size),
            bias: backward ? -1 : 1,
          ),
        );
      } else {
        tr.setSelection(NodeSelection(tr.doc, at));
      }
      return;
    }
    final cell = tableContext(tr.doc, selection.head);
    if (cell != null && selection.empty) {
      final resolved = tr.doc.resolve(selection.head);
      if ((backward && selection.head == cell.cellPosition + 2) ||
          (!backward &&
              selection.head == cell.cellPosition + cell.cell.nodeSize - 2)) {
        return;
      }
      if (!resolved.parent.isTextblock) return;
    }
    if (!selection.empty) {
      tr.replace(selection.from, selection.to);
      final target = selection.from.clamp(0, tr.doc.content.size);
      tr.setSelection(Selection.near(tr.doc, target));
      return;
    }
    final pos = tr.doc.resolve(selection.head);
    if (!pos.parent.isTextblock) return;
    final offset = pos.parentOffset, size = pos.parent.content.size;
    if ((backward && offset == 0) || (!backward && offset == size)) {
      if (backward &&
          pos.parent.type == 'codeBlock' &&
          (pos.pos == 1 || size == 0)) {
        _setBlock(state, tr, 'paragraph', const {});
        while (_lift(tr)) {}
        return;
      }
      if (!backward && _deleteAtItemEnd(tr)) return;
      if (backward && _paragraphIntoList(tr, join: true)) return;
      if (backward && _quoteBackspace(tr)) return;
      if (backward &&
          pos.depth >= 2 &&
          _isItem(pos.node(pos.depth - 1).type) &&
          pos.index(pos.depth - 1) == 0) {
        if (_lift(tr, list: true)) return;
      }
      if (_joinBoundary(tr, backward: backward)) return;
      if (backward &&
          pos.pos == 1 &&
          pos.parent.type != 'paragraph' &&
          size == 0) {
        _setBlock(state, tr, 'paragraph', const {});
      }
      return;
    }
    final text = pos.parent.content
        .map((n) => n.isText ? n.text : '\ufffc')
        .join();
    var count = 0;
    if (word) {
      final segment = backward
          ? text.substring(0, offset)
          : text.substring(offset);
      final match =
          (backward
                  ? RegExp(
                      r'(?:\s+|[\p{L}\p{N}_]+|[^\p{L}\p{N}_\s])$',
                      unicode: true,
                    )
                  : RegExp(
                      r'^(?:\s+|[\p{L}\p{N}_]+|[^\p{L}\p{N}_\s])',
                      unicode: true,
                    ))
              .firstMatch(segment);
      count = match?[0]?.length ?? 0;
    } else {
      count = backward
          ? text.substring(0, offset).characters.last.length
          : text.substring(offset).characters.first.length;
    }
    final from = backward ? selection.head - count : selection.head;
    final to = backward ? selection.head : selection.head + count;
    tr
        .step(ReplaceStep(from, to, Slice.empty))
        .setSelection(TextSelection(from));
  }

  void _history(EditorState state, Transaction tr, bool redo) {
    final h = state.history,
        source = redo ? state.history._undone : state.history._done;
    if (source.isEmpty) return;
    final event = source.last,
        snapshot = redo ? source.last.after : source.last.before;
    tr
        .step(
          _DocumentStep(
            snapshot.doc,
            redo
                ? event.blocks
                : BlockRange(
                    event.blocks.from,
                    event.blocks.newTo,
                    event.blocks.oldTo,
                  ),
          ),
        )
        .setSelection(snapshot.selection)
        .setStoredMarks(snapshot.storedMarks)
        .setMeta('addToHistory', false)
        .setMeta('history', true);
    if (event.nested case final nested?) {
      tr._nestedReplacements
        ..clear()
        ..add(
          redo
              ? nested
              : NestedRange(
                  nested.path,
                  nested.from,
                  nested.newTo,
                  nested.oldTo,
                ),
        );
    }
    tr.mapping = redo ? event.mapping : event.mapping.invert();
    tr._historyOverride = History._(
      h.depth,
      h.groupDelay,
      List.unmodifiable(
        redo ? [...h._done, event] : h._done.sublist(0, h._done.length - 1),
      ),
      List.unmodifiable(
        redo
            ? h._undone.sublist(0, h._undone.length - 1)
            : [...h._undone, event],
      ),
    );
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

class _DocumentStep extends Step {
  const _DocumentStep(this.doc, [this.blocks]);
  final BlockRange? blocks;
  final Node doc;
  @override
  StepResult apply(Node before) => StepResult(
    doc,
    blocks ?? BlockRange(0, before.childCount, doc.childCount),
  );
  @override
  StepMap getMap() => StepMap.empty;
  @override
  Step _inverseFor(Node before, StepResult result) => _DocumentStep(before);
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
    if (!RegExp(r'^(?:```|~~~|···)[a-z]*$').hasMatch(text)) return false;
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
    final ordered = RegExp(r'^([0-9０-９]+)[．.]\s$').firstMatch(text);
    final task = RegExp(r'^\s*(\[([( |x])?\])\s$').firstMatch(text);
    final code =
        RegExp(r'^```([a-z]+)?[\s\n]$').firstMatch(text) ??
        RegExp(r'^~~~([a-z]+)?[\s\n]$').firstMatch(text) ??
        RegExp(r'^···([a-z]+)?[\s\n]$').firstMatch(text);
    final hr =
        RegExp(r'^(?:---|—-|___\s|\*\*\*\s)$').hasMatch(text) ||
        RegExp(r'^(?:—{3,}|－{3,})$').hasMatch(text);
    if (RegExp(r'^\s*([-+*])\s$').hasMatch(text) ||
        RegExp(r'^\s*[－＊·•]\s$').hasMatch(text)) {
      type = 'bulletList';
    } else if (ordered != null) {
      type = 'orderedList';
      final digits = ordered[1]!.runes.map(
        (r) => r >= 0xff10 && r <= 0xff19 ? r - 0xfee0 : r,
      );
      attrs = {'start': int.parse(String.fromCharCodes(digits))};
    } else if (task != null || RegExp(r'^\s*(?:【\s?】|「」)\s$').hasMatch(text)) {
      type = 'taskItem';
      attrs = {'checked': task?[2] == 'x'};
    } else if (RegExp(r'^\s*>\s$').hasMatch(text) ||
        RegExp(r'^\s*[》＞]\s$').hasMatch(text)) {
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

extension _NodeCommands on EditorCommands {
  void _caretAfterSelectedNode(Transaction tr) {
    if (tr.selection is! NodeSelection) return;
    final end = tr.selection.to;
    final after = tr.doc.resolve(end).nodeAfter;
    if (after?.isTextblock == true) {
      tr.setSelection(TextSelection(end + 1));
    } else {
      _paragraphAfter(end, tr);
    }
  }

  void _moveBlock(Transaction tr, int direction) {
    final sel = tr.selection, pos = tr.doc.resolve(tr.selection.from);
    if (sel is! NodeSelection && pos.depth == 0) return;
    var depth = sel is NodeSelection ? pos.depth + 1 : 1;
    if (sel is! NodeSelection) {
      for (var d = pos.depth; d > 0; d--) {
        if (_isItem(pos.node(d).type)) {
          depth = d;
          break;
        }
      }
    }
    final parent = pos.node(depth - 1), index = pos.index(depth - 1);
    final other = index + direction;
    if (other < 0 || other >= parent.childCount) return;
    final node = parent.child(index), sibling = parent.child(other);
    final children = parent.content.toList();
    children[index] = sibling;
    children[other] = node;
    if (!parent.schema.validContent(parent.type, Fragment(children))) return;
    final start = sel is NodeSelection ? sel.from : pos.before(depth);
    final shift = direction < 0 ? -sibling.nodeSize : sibling.nodeSize;
    tr.replace(start, start + node.nodeSize);
    tr.replace(start + shift, start + shift, Slice(Fragment([node]), 0, 0));
    tr.setSelection(
      sel is NodeSelection
          ? NodeSelection(tr.doc, start + shift)
          : TextSelection(sel.anchor + shift, sel.head + shift),
    );
  }
}
