part of '../editor.dart';

final Expando<(TextStyle, bool, double, List<double>)> _columnSizes =
    Expando<(TextStyle, bool, double, List<double>)>();
List<double> _tableColumns(m.Node table, TiptapEditorStyle style) {
  final cached = _columnSizes[table];
  if (cached != null &&
      cached.$1 == style.paragraph &&
      cached.$2 == style.tableFixedLayout &&
      cached.$3 == style.tableMinColumnWidth) {
    return cached.$4;
  }
  final map = m.TableMap.get(table),
      columns = List<double>.filled(map.width, style.tableMinColumnWidth);
  for (var r = 0; r < table.childCount; r++) {
    final row = table.child(r), start = table.content.positionAt(r) + 1;
    for (var c = 0; c < row.childCount; c++) {
      final cell = row.child(c),
          rect = map.findCell(start + row.content.positionAt(c)),
          values = cell.attrs['colwidth'];
      for (var column = rect.left; column < rect.right; column++) {
        final explicit = values is List && column - rect.left < values.length
            ? values[column - rect.left]
            : null;
        columns[column] = math.max(
          columns[column],
          explicit is num && explicit > 0
              ? explicit.toDouble()
              : style.tableFixedLayout
              ? style.tableMinColumnWidth
              : math.min(
                  320,
                  20 +
                      cell.textLength *
                          (style.paragraph.fontSize ?? 17) *
                          .55 /
                          (rect.right - rect.left),
                ),
        );
      }
    }
  }
  _columnSizes[table] = (
    style.paragraph,
    style.tableFixedLayout,
    style.tableMinColumnWidth,
    List.unmodifiable(columns),
  );
  return columns;
}

class _TableCellLayout {
  _TableCellLayout(
    this.node,
    this.position,
    this.column,
    this.colspan,
    this.rowspan,
  );
  final m.Node node;
  final int position, column, colspan, rowspan;
  final List<(_BlockLayout, int, Offset)> blocks = [];
  Rect rect = Rect.zero;
  late m.CellRect grid;
  double continuation = 0;
}

final class _TableRowLayout extends _BlockLayout {
  _TableRowLayout(super.node, this.table, this.rowIndex, this.rowPosition);
  m.Node table;
  int rowIndex, rowPosition;
  final List<_TableCellLayout> cells = [];
  double tableWidth = 0;
  _BlockLayout Function(m.Node)? blockLayout;
  TiptapCodeHighlighter? highlighter;
  double? Function(m.Node node, double width)? nodeHeight;
  double Function(int from, int to)? rowDistance;
  void _releaseCells() {
    for (final cell in cells) {
      for (final block in cell.blocks) {
        block.$1.tableUsers.remove(this);
      }
    }
    cells.clear();
  }

  @override
  void dispose() {
    _releaseCells();
    super.dispose();
  }

  @override
  double get intrinsicWidth => tableWidth;
  @override
  bool layout(
    double width,
    TiptapEditorStyle style,
    TiptapDiagnostics diagnostics, {
    TextStyle? baseStyle,
    TextSpan? codeHighlight,
    TextAlign? textAlign,
    double firstLineIndent = 0,
  }) {
    if (this.width == width && identical(this.style, style)) return false;
    _releaseCells();
    final map = m.TableMap.get(table),
        columns = List<double>.of(_tableColumns(table, style));
    var total = columns.fold(0.0, (a, b) => a + b);
    if (total < width && columns.isNotEmpty) {
      final extra = (width - total) / columns.length;
      for (var c = 0; c < columns.length; c++) {
        columns[c] += extra;
      }
      total = width;
    }
    tableWidth = total;
    var rowHeight = style.tableMinRowHeight;
    final seen = <int>{};
    for (var c = 0; c < map.width; c++) {
      final pos = map.map[rowIndex * map.width + c];
      if (pos == 0 || !seen.add(pos)) continue;
      final cell = table.nodeAt(pos)!,
          rect = map.findCell(pos),
          entry = _TableCellLayout(
            cell,
            pos - rowPosition,
            rect.left,
            rect.right - rect.left,
            rect.bottom - rect.top,
          );
      entry.grid = rect;
      final x = columns.take(rect.left).fold(0.0, (a, b) => a + b),
          w = columns
              .skip(rect.left)
              .take(rect.right - rect.left)
              .fold(0.0, (a, b) => a + b);
      var y = style.tableCellPadding.top;
      m.Node? previous;
      final available = math.max(1.0, w - style.tableCellPadding.horizontal);
      for (final block in cell.rows()) {
        final layout =
            blockLayout?.call(block.node) ?? _BlockLayout(block.node);
        layout.tableUsers.add(this);
        layout.layout(
          available,
          style,
          diagnostics,
          textAlign: switch (cell.attrs['align']) {
            'center' => TextAlign.center,
            'right' => TextAlign.right,
            'justify' => TextAlign.justify,
            _ => TextAlign.left,
          },
          codeHighlight: block.node.type == 'codeBlock'
              ? highlighter?.call(
                  block.node.attrs['language'] as String?,
                  layout.text,
                )
              : null,
          baseStyle: style
              .forBlock(block.node)
              .copyWith(
                fontWeight: cell.type == 'tableHeader' ? FontWeight.w600 : null,
              ),
        );
        final customHeight = nodeHeight?.call(block.node, available);
        if (customHeight != null) layout.height = customHeight;
        y +=
            style.cellBlockGap?.call(previous, block.node) ??
            (previous == null ? 0 : style.tableBlockGap);
        entry.blocks.add((
          layout,
          entry.position + block.position,
          Offset(x + style.tableCellPadding.left, y),
        ));
        y += layout.height;
        previous = block.node;
      }
      y += style.cellBlockGap?.call(previous, null) ?? 0;
      rowHeight = math.max(
        rowHeight,
        (y + style.tableCellPadding.bottom) / entry.rowspan,
      );
      entry.rect = Rect.fromLTWH(x, 0, w, 0);
      cells.add(entry);
    }
    for (final cell in cells) {
      cell.rect = Rect.fromLTWH(cell.rect.left, 0, cell.rect.width, rowHeight);
      cell.continuation = (rowIndex - cell.grid.top) * rowHeight;
    }
    height = rowHeight;
    this.width = width;
    this.style = style;
    return true;
  }

  Offset _blockOrigin(_TableCellLayout cell, Offset point) =>
      point -
      Offset(
        0,
        rowDistance?.call(cell.grid.top, rowIndex) ?? cell.continuation,
      );
  (_BlockLayout, int, Offset)? _block(int position) {
    (_BlockLayout, int, Offset)? best;
    for (final cell in cells) {
      for (final block in cell.blocks) {
        if (position >= block.$2 &&
            position <= block.$2 + block.$1.node.nodeSize) {
          return (block.$1, block.$2, _blockOrigin(cell, block.$3));
        }
        best ??= (block.$1, block.$2, _blockOrigin(cell, block.$3));
      }
    }
    return best;
  }

  @override
  _CaretGeometry caretGeometry(int offset, double width, double factor) {
    final block = _block(offset + 1)!;
    return block.$1
        .caretGeometry(
          (offset - block.$2).clamp(0, block.$1.node.content.size),
          width,
          factor,
        )
        .shift(block.$3);
  }

  @override
  Rect caret(int offset, double caretWidth) {
    final block = _block(offset + 1);
    if (block == null) return Rect.fromLTWH(0, 0, caretWidth, 24);
    return block.$1
        .caret(
          (offset - block.$2).clamp(0, block.$1.node.content.size),
          caretWidth,
        )
        .shift(block.$3);
  }

  @override
  int position(Offset offset) {
    final cell = cells.firstWhere(
      (c) => offset.dx < c.rect.right,
      orElse: () => cells.last,
    );
    var block = cell.blocks.last;
    for (final b in cell.blocks) {
      if (offset.dy < _blockOrigin(cell, b.$3).dy + b.$1.height) {
        block = b;
        break;
      }
    }
    return block.$2 + block.$1.position(offset - _blockOrigin(cell, block.$3));
  }

  @override
  List<Rect> boxes(int from, int to) => [
    for (final cell in cells)
      for (final block in cell.blocks)
        ...block.$1
            .boxes(
              (from - block.$2).clamp(0, block.$1.node.content.size),
              (to - block.$2).clamp(0, block.$1.node.content.size),
            )
            .map(
              (r) => r.shift(_blockOrigin(cell, block.$3)).intersect(cell.rect),
            )
            .where((r) => !r.isEmpty),
  ];
  @override
  TextRange boundary(int offset, {required bool word}) {
    final block = _block(offset + 1);
    if (block == null) return const TextRange.collapsed(0);
    final range = block.$1.boundary(
      (offset - block.$2).clamp(0, block.$1.node.content.size),
      word: word,
    );
    return TextRange(start: range.start + block.$2, end: range.end + block.$2);
  }

  void paint(
    Canvas canvas,
    Offset origin,
    TiptapEditorStyle style,
    m.Selection selection,
    int position,
    m.SearchIndex search,
  ) {
    canvas.save();
    canvas.clipRect(origin & Size(tableWidth, height));
    for (final cell in cells) {
      final rect = cell.rect.shift(origin);
      if (cell.node.type == 'tableHeader') {
        canvas.drawRect(rect, Paint()..color = style.codeBackground);
      }
      if (selection is m.CellSelection &&
          selection.cells.contains(position + cell.position)) {
        canvas.drawRect(rect, Paint()..color = style.selectionColor);
      }
      final border = Paint()
        ..color = style.opaqueBorder
        ..strokeWidth = 1;
      canvas.drawLine(rect.topLeft, rect.bottomLeft, border);
      canvas.drawLine(rect.topRight, rect.bottomRight, border);
      if (cell.grid.top == rowIndex) {
        canvas.drawLine(rect.topLeft, rect.topRight, border);
      }
      if (cell.grid.bottom == rowIndex + 1) {
        canvas.drawLine(rect.bottomLeft, rect.bottomRight, border);
      }
      if (search.query.isNotEmpty) {
        for (final hit in search.knownMatches(cell.node)) {
          for (final block in cell.blocks) {
            final blockStart = block.$2 - cell.position;
            for (final box in block.$1.boxes(
              (hit.from - 1 - blockStart).clamp(0, block.$1.node.content.size),
              (hit.to - 1 - blockStart).clamp(0, block.$1.node.content.size),
            )) {
              canvas.drawRect(
                box.shift(origin + _blockOrigin(cell, block.$3)),
                Paint()..color = const Color(0x66ffcc00),
              );
            }
          }
        }
      }
      canvas.save();
      canvas.clipRect(rect);
      for (final block in cell.blocks) {
        if (nodeHeight?.call(block.$1.node, cell.rect.width - 20) != null) {
          continue;
        }
        var point = origin + _blockOrigin(cell, block.$3);
        for (final chunk in block.$1.chunks) {
          _paintInlineChunk(canvas, chunk, point, style);
          point += Offset(0, chunk.height);
        }
      }
      canvas.restore();
    }
    canvas.restore();
  }
}
