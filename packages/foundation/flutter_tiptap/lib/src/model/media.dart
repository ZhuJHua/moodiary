part of '../model.dart';

const _mediaTypes = {'image', 'video', 'audio', 'attachment'};

@internal
bool isResizableMedia(Node node) =>
    node.type == 'image' || node.type == 'video';

@internal
bool isMediaNode(Node? node) => node != null && _mediaTypes.contains(node.type);

@internal
double mediaWidthFactor(Node node, {int? preview}) {
  final value = preview ?? node.attrs['widthPercent'];
  return value is int
      ? clampWidthPercent(value)! / 100
      : value is num
      ? value.clamp(25, 100) / 100
      : 1;
}

int? clampWidthPercent(Object? value) =>
    value is num && value.isFinite ? value.round().clamp(25, 100) : null;

Map<String, Object?>? _normalizeNodeAttrs(
  String type,
  Map<String, Object?>? raw,
) {
  if (raw == null) return null;
  final attrs = {...raw};
  if (type == 'image') {
    attrs.remove('width');
    attrs.remove('height');
    final alt = attrs.remove('alt'), title = attrs.remove('title');
    attrs['name'] ??= alt is String && alt.isNotEmpty
        ? alt
        : title is String && title.isNotEmpty
        ? title
        : null;
    if (attrs.containsKey('widthPercent')) {
      attrs['widthPercent'] = clampWidthPercent(attrs['widthPercent']);
    }
  } else if (type == 'audio' || type == 'video') {
    final filename = attrs.remove('filename');
    if (filename is String) attrs['src'] ??= filename;
  } else if (type == referenceNodeType) {
    attrs.remove('mentionSuggestionChar');
  }
  return attrs;
}

extension _MediaCommands on EditorCommands {
  void _insertAtom(Transaction tr, Node node) {
    final sel = tr.selection, pos = tr.doc.resolve(tr.selection.from);
    var start = sel.from;
    if (sel is NodeSelection) {
      start = sel.to;
      tr.replace(start, start, Slice(Fragment([node]), 0, 0));
    } else if (pos.depth == 0) {
      tr.replace(start, start, Slice(Fragment([node]), 0, 0));
    } else {
      var depth = 1;
      for (var d = pos.depth; d >= 1; d--) {
        final parent = pos.node(d - 1), index = pos.index(d - 1);
        if (parent.canReplace(index + 1, index + 1, Fragment([node]))) {
          depth = d;
          break;
        }
      }
      final block = pos.node(depth),
          parent = pos.node(depth - 1),
          index = pos.index(depth - 1);
      if (block.type == 'paragraph' &&
          block.content.isEmpty &&
          parent.canReplace(index, index + 1, Fragment([node]))) {
        start = pos.before(depth);
        tr.replace(start, pos.after(depth), Slice(Fragment([node]), 0, 0));
      } else {
        start = pos.after(depth);
        tr.replace(start, start, Slice(Fragment([node]), 0, 0));
      }
    }
    _paragraphAfter(start + node.nodeSize, tr);
  }
}

extension _MediaHelpers on EditorCommands {
  void _setMediaAttrs(Transaction tr, String name, Map<String, dynamic> args) {
    final selection = tr.selection;
    if (selection is NodeSelection) {
      final node = tr.doc.nodeAt(selection.from)!;
      if (name == 'setMediaWidth' && isResizableMedia(node)) {
        final raw = args['percent'];
        final percent = raw == null
            ? null
            : clampWidthPercent(
                raw is num ? raw : num.tryParse(raw.toString()),
              );
        if (raw == null || percent != null) {
          tr.step(AttrStep(selection.from, 'widthPercent', percent));
        }
      } else if (name == 'setMediaName' && isMediaNode(node)) {
        final value = (args['name'] as String? ?? '').trim();
        tr.step(AttrStep(selection.from, 'name', value.isEmpty ? null : value));
      }
    }
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
    tr.blockMove = (before: start, after: start + shift);
    tr.setMeta('closeHistory', true);
  }
}

extension _MediaDispatch on EditorCommands {
  void _deleteSelectedBlock(EditorState state, Transaction tr) {
    if (tr.selection is NodeSelection) {
      _delete(state, tr, backward: true, word: false);
    }
  }
}
