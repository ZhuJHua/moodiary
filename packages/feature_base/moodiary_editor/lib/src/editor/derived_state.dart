part of '../moodiary_editor.dart';

extension _HostDerivedState on MoodiaryEditorHost {
  void _deriveState() {
    final s = editor.state,
        t = s.toolbar,
        pos = s.doc.resolve(s.selection.from);
    String? listType;
    var quote = false;
    for (var d = pos.depth; d > 0; d--) {
      final type = pos.node(d).type;
      if (listType == null &&
          const {'bulletList', 'orderedList', 'taskList'}.contains(type)) {
        listType = type;
      }
      quote |= type == 'blockquote';
    }
    final parent = pos.parent,
        selected = s.selection is ft.NodeSelection
            ? s.doc.nodeAt(s.selection.from)
            : null;
    final adjacentRule = _adjacentRule();
    final actionNode =
        selected ?? (adjacentRule == null ? null : s.doc.nodeAt(adjacentRule));
    final nodeType = EditorNodeType.values.asNameMap()[actionNode?.type];
    final link = ft.linkAt(s.doc, s.selection.from);
    final block = parent.type == 'heading'
        ? EditorBlock.values.asNameMap()['heading${parent.attrs['level']}'] ??
              EditorBlock.paragraph
        : parent.type == 'codeBlock'
        ? EditorBlock.codeBlock
        : quote
        ? EditorBlock.blockquote
        : EditorBlock.paragraph;
    final marks = {
      for (final mark in EditorMark.values)
        if (t.activeMarks.contains(mark.name) ||
            mark == EditorMark.link && link != null)
          mark,
    };
    final indentKey = (s.doc, s.selection, _protected);
    if (_indentKey != indentKey) {
      _indentKey = indentKey;
      _indentCommands = (
        !_protected &&
            listType != null &&
            editor.commands.execute(s, 'sinkListItem').docChanged,
        !_protected &&
            listType != null &&
            editor.commands.execute(s, 'liftListItem').docChanged,
      );
    }
    final selectedText = selected != null || s.selection.empty
        ? ''
        : editor.selectedTextPrefix(maxLength: 200).replaceAll('\n', ' ');
    _state.value = EditorState(
      contentError: _protected,
      marks: marks,
      block: block,
      list: switch (listType) {
        'bulletList' => EditorList.bullet,
        'orderedList' => EditorList.ordered,
        'taskList' => EditorList.task,
        _ => null,
      },
      canIndent: _indentCommands.$1,
      canOutdent: _indentCommands.$2,
      canUndo: s.history.canUndo,
      canRedo: s.history.canRedo,
      selection: selected != null
          ? EditorSelectionKind.node
          : s.selection.empty
          ? EditorSelectionKind.caret
          : EditorSelectionKind.text,
      node: nodeType == null
          ? null
          : (type: nodeType, attrs: actionNode!.attrs),
      inTable: t.inTable,
      link: link == null
          ? null
          : (href: link.href, text: _textBetween(link.from, link.to)),
      selectedText: selectedText,
    );
  }

  int? _adjacentRule() {
    final selection = editor.state.selection;
    if (!selection.empty) return null;
    final pos = editor.state.doc.resolve(selection.head);
    if (pos.parent.isTextblock) {
      if (pos.parentOffset == 0 &&
          pos.depth > 0 &&
          editor.state.doc.resolve(pos.before()).nodeBefore?.type ==
              'horizontalRule') {
        return pos.before() - 1;
      }
      if (pos.parentOffset == pos.parent.content.size &&
          pos.depth > 0 &&
          editor.state.doc.resolve(pos.after()).nodeAfter?.type ==
              'horizontalRule') {
        return pos.after();
      }
    } else {
      if (pos.nodeBefore?.type == 'horizontalRule') return pos.pos - 1;
      if (pos.nodeAfter?.type == 'horizontalRule') return pos.pos;
    }
    return null;
  }
}
