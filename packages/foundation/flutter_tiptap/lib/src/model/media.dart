part of '../model.dart';

const _mediaTypes = {'image', 'video', 'audio', 'attachment'};

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
