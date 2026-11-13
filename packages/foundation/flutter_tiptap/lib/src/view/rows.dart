part of '../editor.dart';

var _orderedGutters = Expando<LinkedHashMap<TiptapEditorStyle, double>>();

double _listGutter(m.Node list, TiptapEditorStyle style) {
  if (list.type != 'orderedList') return style.listIndent;
  final cache = _orderedGutters[list] ??= LinkedHashMap();
  final cached = cache.remove(style);
  if (cached != null) {
    cache[style] = cached;
    return cached;
  }
  double measure(String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style.paragraph),
      textDirection: style.textDirection,
    )..layout();
    final width = painter.maxIntrinsicWidth;
    painter.dispose();
    return width;
  }

  final start = (list.attrs['start'] as num? ?? 1).toInt(),
      end = start + math.max(0, list.childCount - 1);
  var width = 0.0;
  if (list.childCount <= 32) {
    for (var index = 0; index < list.childCount; index++) {
      width = math.max(width, measure('${start + index}.'));
    }
  } else {
    var widest = '0', digitWidth = 0.0;
    for (var digit = 0; digit < 10; digit++) {
      final measured = measure('$digit');
      if (measured > digitWidth) {
        widest = '$digit';
        digitWidth = measured;
      }
    }
    final digits = math.max(start.abs(), end.abs()).toString().length;
    width = measure('${start < 0 ? '-' : ''}${widest * digits}.');
  }
  final gutter = math.max(style.listIndent, width + 8);
  cache[style] = gutter;
  if (cache.length > 8) cache.remove(cache.keys.first);
  return gutter;
}

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
  double indent;
  final double minHeight;
  late final double _naturalIndent = indent;
  late final List<(double, int)> _naturalQuotes = List.of(quotes);
  double markerGutter = 0;
  double _naturalMarkerGutter = 0;
  final EdgeInsets codePadding;
  final List<(double, int)> quotes;
  final String? marker;
  final int? taskPosition;
  final bool checked, taskChecked, quoteColor, compact;
  final int? listEnd;
  m.Node get node => value.node;
  int get position => value.position;
  void fit(double width, TiptapEditorStyle style) {
    final minimum = math.min(width / 2, 96.0);
    final scale = _naturalIndent == 0
        ? 1.0
        : math.min(1.0, math.max(0.0, width - minimum) / _naturalIndent);
    indent = _naturalIndent * scale;
    markerGutter = _naturalMarkerGutter * scale;
    for (var index = 0; index < quotes.length; index++) {
      quotes[index] = (_naturalQuotes[index].$1 * scale, quotes[index].$2);
    }
  }

  static _Row at(m.Node doc, int index, TiptapEditorStyle style) {
    final value = doc.rowAt(index);
    var parent = doc,
        position = doc.type == 'doc' ? -1 : 0,
        indent = 0.0,
        listDepth = 0,
        taskDepth = 0;
    var minHeight = 0.0;
    final quotes = <(double, int)>[];
    String? marker;
    var markerGutter = 0.0, currentGutter = 0.0;
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
          currentGutter = _listGutter(child, style);
          indent += currentGutter;
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
          markerGutter = currentGutter;
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
      quotes,
      marker,
      taskPosition,
      checked,
      taskChecked,
      quoteColor,
      compact,
      listEnd,
      style.codeBlockPadding,
      minHeight,
    ).._naturalMarkerGutter = markerGutter;
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

  double spacing(m.Node root, int index, TiptapEditorStyle style) {
    if (node.type == 'tableRow' && tableRow + 1 < table!.childCount) return 0;
    final next = index + 1 < root.rowCount
        ? _Row.at(root, index + 1, style)
        : null;
    if (compact && next != null && next.position < listEnd!) return 0;
    final gap = root.type == 'doc' ? style.blockGap : style.cellBlockGap;
    if (gap != null) {
      final previous = root.child(value.path.first);
      if (next == null) return gap(previous, null);
      if (value.path.first != next.value.path.first) {
        return gap(previous, root.child(next.value.path.first));
      }
    }
    if (root.type != 'doc' && next == null) return 0;
    if (next?.node.type == 'heading' &&
        next!.value.path.length == 1 &&
        style.headingTopSpacing != null) {
      return style.headingTopSpacing![(next.node.attrs['level'] as int) - 1];
    }
    if (node.type == 'heading' &&
        value.path.length == 1 &&
        style.headingBottomSpacing != null) {
      return style.headingBottomSpacing!;
    }
    return root.type == 'doc' ? style.blockSpacing : style.tableBlockGap;
  }
}

class _CellRow {
  _CellRow(
    this.row,
    this.layout,
    this.position,
    this.origin,
    this.width,
    this.spacing,
  );

  final _Row row;
  final _BlockLayout layout;
  final int position;
  final Offset origin;
  final double width, spacing;
  double scrollOffset = 0;
  Rect? clip;
  double get height => layout.height + row.codeTop + row.codeBottom;
  Offset get textOrigin =>
      origin + Offset(row.codeInset - scrollOffset, row.codeTop);
  Rect get rect => origin & Size(width, height);

  _CellRow shifted(int positionOffset, Offset offset, Rect bounds) =>
      _CellRow(
          row,
          layout,
          position + positionOffset,
          origin + offset,
          width,
          spacing,
        )
        ..scrollOffset = scrollOffset
        ..clip = (clip?.shift(offset) ?? bounds).intersect(bounds);
}
