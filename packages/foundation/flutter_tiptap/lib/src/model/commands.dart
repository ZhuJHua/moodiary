part of '../model.dart';

/// Builds transactions for named editing, formatting and structural commands.
class EditorCommands {
  const EditorCommands({this.trailingParagraph = false});
  final bool trailingParagraph;

  Transaction execute(
    EditorState state,
    String name, [
    Map<String, dynamic> args = const {},
  ]) => _execute(state, state.tr, name, args);

  Transaction _execute(
    EditorState state,
    Transaction tr,
    String name,
    Map<String, dynamic> args,
  ) {
    final before = tr.doc;
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
        _setMediaAttrs(tr, name, args);
      case 'deleteBlock':
        _deleteSelectedBlock(state, tr);
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
      case 'insertCommittedLines':
        _insertCommittedLines(
          state,
          tr,
          args['text'] as String,
          args['composition'],
        );
      case 'pasteSlice':
        _pasteSlice(tr, args);
      case 'insertText':
        _insertText(
          state,
          tr,
          args['text'] as String,
          committed: args['committed'] != false,
          composition: args['composition'],
        );
      case 'commitComposition':
        _commitComposition(state, tr, args);
      case 'deleteBackward':
        _deleteBackward(state, tr, args);
      case 'deleteForward':
        _delete(state, tr, backward: false, word: args['word'] == true);
      case 'splitBlock':
        _splitBlock(state, tr);
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
        _toggleBlockquote(tr);
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
        _toggleTaskItem(tr, args);
      case 'joinBackward':
        _joinBoundary(tr, backward: true);
      case 'joinForward':
        _joinBoundary(tr, backward: false);
      case 'selectNodeBackward':
        _joinBoundary(tr, backward: true, selectOnly: true);
      case 'exitCode':
        _codeEnter(tr, exit: true);
      case 'arrowDown':
        _arrowDown(tr);
      case 'tab':
        _tab(tr);
      case 'shiftTab':
        _shiftTab(tr);
      case 'hardBreak':
        _hardBreak(state, tr);
      case 'toggleMark':
        _toggleMark(
          state,
          tr,
          args['type'] as String,
          (args['attrs'] as Map?)?.cast<String, Object?>(),
        );
      case 'setHeading':
      case 'toggleHeading':
        _heading(state, tr, name, args);
      case 'setParagraph':
        _setBlock(state, tr, 'paragraph', const {});
      case 'clearFormatting':
        _clearFormatting(state, tr);
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
    if (name == 'splitBlock' && !identical(before, tr.doc)) {
      _autolinkBeforeSplit(tr);
    }
    if (name == 'pasteText' || name == 'pasteSlice') {
      tr.setMeta('closeHistory', true);
    }
    if (trailingParagraph &&
        !identical(before, tr.doc) &&
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

  void _setBlock(
    EditorState state,
    Transaction tr,
    String type,
    Map<String, Object?> attrs, {
    bool clear = true,
  }) {
    final positions = <int>[];
    tr.doc.nodesBetween(
      state.selection.from,
      state.selection.empty
          ? math.min(tr.doc.content.size, state.selection.to + 1)
          : state.selection.to,
      (node, position, parent, index) {
        if (!node.isTextblock) return true;
        positions.add(position);
        return false;
      },
    );
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
}
