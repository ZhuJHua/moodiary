part of '../editor.dart';

class _Row {
  _Row(
    this.value,
    this.indent,
    this.quotes,
    this.marker,
    this.taskPosition,
    this.checked,
    this.taskChecked,
    this.quoteColor,
    this.compact,
    this.listEnd,
    this.codePadding,
    this.minHeight,
  );
  m.Node? table;
  int tableRow = 0, tableRowPosition = 0;
  final m.DocumentRow value;
  final double indent, minHeight;
  final EdgeInsets codePadding;
  final List<(double, int)> quotes;
  final String? marker;
  final int? taskPosition;
  final bool checked, taskChecked, quoteColor, compact;
  final int? listEnd;
  m.Node get node => value.node;
  int get position => value.position;
  static _Row at(m.Node doc, int index, TiptapEditorStyle style) {
    final value = doc.rowAt(index);
    var parent = doc, position = -1, indent = 0.0, listDepth = 0, taskDepth = 0;
    var minHeight = 0.0;
    final quotes = <(double, int)>[];
    String? marker;
    int? taskPosition;
    var checked = false,
        taskChecked = false,
        quoteColor = false,
        compact = false;
    int? listEnd;
    for (final childIndex in value.path) {
      final child = parent.child(childIndex);
      position += 1 + parent.content.positionAt(childIndex);
      if (child.type == 'blockquote') {
        quotes.add((indent, position));
        indent += style.quoteIndent;
        quoteColor = true;
      } else if (const {
        'bulletList',
        'orderedList',
        'taskList',
      }.contains(child.type)) {
        if (child.type == 'taskList') {
          indent +=
              (style.taskIndent ?? style.listIndent) +
              (taskDepth > 0 ? style.nestedTaskIndent : 0);
          taskDepth++;
        } else {
          indent += style.listIndent;
        }
        listDepth++;
        listEnd ??= position + child.nodeSize - 1;
      } else if (child.type == 'listItem' || child.type == 'taskItem') {
        // Only the first row in an item gets its marker/checkbox.
        final firstRow = child.rowCount > 0 && value.position == position + 1;
        if (child.type == 'taskItem') {
          checked |= child.attrs['checked'] == true;
          if (child.rowCount == 1) minHeight = style.taskMinHeight;
          if (firstRow) {
            taskPosition = position;
            taskChecked = child.attrs['checked'] == true;
          }
        } else if (firstRow) {
          marker = parent.type == 'orderedList'
              ? '${(parent.attrs['start'] as num? ?? 1).toInt() + childIndex}.'
              : style.bulletGlyphs[(listDepth - 1) % style.bulletGlyphs.length];
        }
      }
      if (child.isTextblock) {
        compact =
            (parent.type == 'listItem' || parent.type == 'taskItem') &&
            child.type != 'codeBlock';
      }
      parent = child;
    }
    final result = _Row(
      value,
      indent,
      List.unmodifiable(quotes),
      marker,
      taskPosition,
      checked,
      taskChecked,
      quoteColor,
      compact,
      listEnd,
      style.codeBlockPadding,
      minHeight,
    );
    var ancestor = doc;
    for (final childIndex in value.path) {
      if (ancestor.type == 'table') {
        result.table = ancestor;
        result.tableRow = childIndex;
        result.tableRowPosition = ancestor.content.positionAt(childIndex);
      }
      ancestor = ancestor.child(childIndex);
    }
    return result;
  }

  double get codeInset => node.type == 'codeBlock' ? codePadding.left : 0;
  double get codeTop => node.type == 'codeBlock' ? codePadding.top : 0;
  double get codeBottom => node.type == 'codeBlock' ? codePadding.bottom : 0;
  TextStyle textStyle(TiptapEditorStyle style) {
    var base = style.forBlock(node);
    if (quoteColor) base = base.copyWith(color: style.markerColor);
    if (checked) {
      base = base.copyWith(
        color: style.markerColor,
        decoration: TextDecoration.lineThrough,
      );
    }
    return base;
  }
}
