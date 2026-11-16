part of '../model.dart';

extension _MarksHelpers on EditorCommands {
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
    if (from == to) return;
    state.doc.nodesBetween(from, to, (node, position, parent, index) {
      if (node.isText || node.marks.isNotEmpty) visit(node);
      return !node.isOpaque;
    });
  }
}

extension _MarksDispatch on EditorCommands {
  void _clearFormatting(EditorState state, Transaction tr) {
    if (state.selection.empty) {
      tr.setStoredMarks(const []);
    } else {
      final marks = <Mark>{};
      _visitSelected(state, (n) => marks.addAll(n.marks));
      for (final mark in marks) {
        tr.step(RemoveMarkStep(state.selection.from, state.selection.to, mark));
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
  }
}
