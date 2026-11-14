part of '../editor.dart';

var _columnSizes =
    Expando<_LruMap<(TiptapEditorStyle, double), List<double>>>();

double _tableContentMinWidth(
  m.Node node,
  TiptapEditorStyle style, {
  int taskDepth = 0,
}) {
  final text = math.max(
    1.0,
    style.tableMinColumnWidth - style.tableCellPadding.horizontal,
  );
  double children() => node.content.fold(
    text,
    (width, child) => math.max(
      width,
      _tableContentMinWidth(
        child,
        style,
        taskDepth: taskDepth + (node.type == 'taskList' ? 1 : 0),
      ),
    ),
  );
  switch (node.type) {
    case 'codeBlock':
      return math.max(
        style.tableCodeMinWidth,
        math.max(80, style.codeBlockPadding.horizontal + 64),
      );
    case 'horizontalRule':
      return text + 24;
    case 'blockquote':
    case 'bulletList':
    case 'orderedList':
    case 'taskList':
      return children() +
          _containerIndent(node, style, taskDepth, quoteBorder: true);
    case 'table':
      return text;
    default:
      return node.isTextblock
          ? text
          : node.isLeaf
          ? style.tableMediaMinWidth
          : children();
  }
}

List<double> _tableColumns(
  m.Node table,
  TiptapEditorStyle style,
  double width,
) {
  final cache = _columnSizes[table] ??= _LruMap(8);
  final key = (style, width), cached = cache[key];
  if (cached != null) return cached;
  final map = m.TableMap.get(table),
      minimums = List<double>.filled(map.width, style.tableMinColumnWidth),
      preferred = List<double?>.filled(map.width, null),
      spans = <(m.CellRect, double)>[];
  for (var rowIndex = 0; rowIndex < table.childCount; rowIndex++) {
    final row = table.child(rowIndex),
        start = table.content.positionAt(rowIndex) + 1;
    for (var cellIndex = 0; cellIndex < row.childCount; cellIndex++) {
      final cell = row.child(cellIndex),
          rect = map.findCell(start + row.content.positionAt(cellIndex)),
          values = cell.attrs['colwidth'],
          minimum =
              _tableContentMinWidth(cell, style) +
              style.tableCellPadding.horizontal;
      if (rect.right - rect.left == 1) {
        minimums[rect.left] = math.max(minimums[rect.left], minimum);
      } else {
        spans.add((rect, minimum));
      }
      for (var column = rect.left; column < rect.right; column++) {
        final explicit = values is List && column - rect.left < values.length
            ? values[column - rect.left]
            : null;
        if (explicit is num && explicit.isFinite && explicit > 0) {
          preferred[column] = math.max(
            preferred[column] ?? 0,
            explicit.toDouble(),
          );
        }
      }
    }
  }
  final columns = [
    for (var column = 0; column < map.width; column++)
      math.max(minimums[column], preferred[column] ?? width / map.width),
  ];
  for (final (rect, minimum) in spans) {
    final current = columns
        .skip(rect.left)
        .take(rect.right - rect.left)
        .fold(0.0, (sum, column) => sum + column);
    if (current >= minimum) continue;
    final extra = (minimum - current) / (rect.right - rect.left);
    for (var column = rect.left; column < rect.right; column++) {
      columns[column] += extra;
    }
  }
  final result = List<double>.unmodifiable(columns);
  cache[key] = result;
  return result;
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
  final List<_CellRow> blocks = [];
  Rect rect = Rect.zero;
  late m.CellRect grid;
  double continuation = 0;
}

class _MeasuredCell {
  _MeasuredCell(_TableCellLayout cell)
    : node = cell.node,
      position = cell.position,
      grid = cell.grid,
      rect = cell.rect,
      blocks = [
        for (final block in cell.blocks)
          (
            row: block.row,
            position: block.position,
            origin: block.origin,
            width: block.width,
            spacing: block.spacing,
          ),
      ];
  final m.Node node;
  final int position;
  final m.CellRect grid;
  final Rect rect;
  final List<
    ({_Row row, int position, Offset origin, double width, double spacing})
  >
  blocks;
}

class _TableGeometry {
  bool spans = false;
  double? width;
  TiptapEditorStyle? style;
  int generation = 0;
  List<List<_MeasuredCell>> rows = [];
  List<double> offsets = [];
  double tableWidth = 0;

  void invalidate() {
    width = null;
    rows = [];
    offsets = [];
    generation++;
  }

  void layout(
    _TableRowLayout owner,
    double availableWidth,
    TiptapEditorStyle style,
  ) {
    if (width == availableWidth && identical(this.style, style)) return;
    final cells = <_TableCellLayout>[];
    final table = owner.table,
        map = m.TableMap.get(table),
        columns = _tableColumns(table, style, availableWidth),
        heights = List<double>.filled(
          map.hasRowspan ? map.height : 1,
          style.tableMinRowHeight,
        );
    spans = map.hasRowspan;
    tableWidth = columns.fold(0.0, (total, column) => total + column);
    final positions = spans
        ? map.map
        : map.map.skip(owner.rowIndex * map.width).take(map.width);
    for (final position in positions.toSet()) {
      if (position == 0) continue;
      final cell = table.nodeAt(position)!,
          rect = map.findCell(position),
          entry = _TableCellLayout(
            cell,
            position,
            rect.left,
            rect.right - rect.left,
            rect.bottom - rect.top,
          )..grid = rect;
      final left = columns
              .take(rect.left)
              .fold(0.0, (sum, value) => sum + value),
          cellWidth = columns
              .skip(rect.left)
              .take(entry.colspan)
              .fold(0.0, (sum, value) => sum + value),
          available = math.max(
            1.0,
            cellWidth - style.tableCellPadding.horizontal,
          );
      for (var index = 0; index < cell.rowCount; index++) {
        final row = _Row.at(cell, index, style),
            layout = owner.host.blockLayout(row);
        owner.host.layoutRow(
          row,
          layout,
          available,
          textAlign: switch (cell.attrs['align']) {
            'center' => TextAlign.center,
            'right' => TextAlign.right,
            'justify' => TextAlign.justify,
            _ => null,
          },
          header: cell.type == 'tableHeader',
        );
        owner.host.releaseMeasurement(layout);
        entry.blocks.add(
          _CellRow(
            row,
            layout,
            position + row.position,
            Offset.zero,
            math.max(1, available - row.indent),
            row.spacing(cell, index, style),
          ),
        );
      }
      var top =
          style.tableCellPadding.top +
          (style.cellBlockGap?.call(null, cell.child(0)) ?? 0);
      for (var index = 0; index < entry.blocks.length; index++) {
        final block = entry.blocks[index];
        entry.blocks[index] = _CellRow(
          block.row,
          block.layout,
          block.position,
          Offset(left + style.tableCellPadding.left + block.row.indent, top),
          block.width,
          block.spacing,
        );
        top += block.height + block.spacing;
      }
      entry.rect = Rect.fromLTWH(
        left,
        0,
        cellWidth,
        top + style.tableCellPadding.bottom,
      );
      if (entry.rowspan == 1) {
        final row = spans ? rect.top : 0;
        heights[row] = math.max(heights[row], entry.rect.height);
      }
      cells.add(entry);
    }
    final spanningCells = cells.where((cell) => cell.rowspan > 1).toList()
      ..sort((first, second) => first.rowspan.compareTo(second.rowspan));
    for (final cell in spanningCells) {
      final used = heights
          .skip(cell.grid.top)
          .take(cell.rowspan)
          .fold(0.0, (sum, height) => sum + height);
      final deficit = math.max(0.0, cell.rect.height - used) / cell.rowspan;
      for (var index = cell.grid.top; index < cell.grid.bottom; index++) {
        heights[index] += deficit;
      }
    }
    offsets = [0];
    for (final height in heights) {
      offsets.add(offsets.last + height);
    }
    rows = List.generate(heights.length, (_) => []);
    for (final cell in cells) {
      final measured = _MeasuredCell(cell);
      for (var index = cell.grid.top; index < cell.grid.bottom; index++) {
        rows[spans ? index : 0].add(measured);
      }
    }
    for (final row in rows) {
      row.sort((first, second) => first.grid.left.compareTo(second.grid.left));
    }
    width = availableWidth;
    this.style = style;
    generation++;
  }
}

abstract interface class _LayoutHost {
  int get layoutGeneration;
  int get codeOffsetGeneration;
  _BlockLayout blockLayout(_Row row);
  void layoutRow(
    _Row row,
    _BlockLayout layout,
    double available, {
    bool header = false,
    TextAlign? textAlign,
  });
  void releaseMeasurement(_BlockLayout layout);
  double codeOffset(_CellRow row);
}

final class _TableRowLayout extends _BlockLayout {
  _TableRowLayout(
    super.node,
    this.table,
    this.rowIndex,
    this.rowPosition,
    this.host,
  );
  final _LayoutHost host;
  m.Node table;
  int rowIndex, rowPosition;
  final List<_TableCellLayout> cells = [];
  double tableWidth = 0;
  _TableGeometry geometry = _TableGeometry();
  int _generation = -1;
  (int, int)? _contentGeneration;
  final _contentRows = <bool, List<(_CellRow, _TableCellLayout)>>{};

  void invalidate() {
    width = null;
    geometry.invalidate();
  }

  void _releaseCells() {
    _contentRows.clear();
    for (final cell in cells) {
      for (final block in cell.blocks) {
        block.layout.tableUsers.remove(this);
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
    geometry.layout(this, width, style);
    if (this.width == width &&
        identical(this.style, style) &&
        _generation == geometry.generation) {
      return false;
    }
    _releaseCells();
    tableWidth = geometry.tableWidth;
    final localRow = geometry.spans ? rowIndex : 0;
    final rowHeight =
        geometry.offsets[localRow + 1] - geometry.offsets[localRow];
    for (final source in geometry.rows[localRow]) {
      final cell = source.node,
          rect = source.grid,
          entry = _TableCellLayout(
            cell,
            source.position - rowPosition,
            rect.left,
            rect.right - rect.left,
            rect.bottom - rect.top,
          );
      entry.grid = rect;
      for (final block in source.blocks) {
        final layout = host.blockLayout(block.row);
        host.layoutRow(
          block.row,
          layout,
          block.width + block.row.indent,
          header: cell.type == 'tableHeader',
          textAlign: switch (cell.attrs['align']) {
            'center' => TextAlign.center,
            'right' => TextAlign.right,
            'justify' => TextAlign.justify,
            _ => null,
          },
        );
        layout.tableUsers.add(this);
        entry.blocks.add(
          _CellRow(
            block.row,
            layout,
            block.position - rowPosition,
            block.origin,
            block.width,
            block.spacing,
          ),
        );
      }
      entry.rect = Rect.fromLTWH(source.rect.left, 0, source.rect.width, 0);
      cells.add(entry);
    }
    cells.sort((first, second) => first.grid.left.compareTo(second.grid.left));
    for (final cell in cells) {
      cell.rect = Rect.fromLTWH(cell.rect.left, 0, cell.rect.width, rowHeight);
      cell.continuation = geometry.spans
          ? geometry.offsets[rowIndex] - geometry.offsets[cell.grid.top]
          : 0;
    }
    height = rowHeight;
    this.width = width;
    this.style = style;
    _generation = geometry.generation;
    return true;
  }

  Offset _blockOrigin(_TableCellLayout cell, Offset point) =>
      point - Offset(0, cell.continuation);
  Offset _textOrigin(_TableCellLayout cell, _CellRow block) {
    block.scrollOffset = host.codeOffset(block);
    return _blockOrigin(cell, block.textOrigin);
  }

  Iterable<(_CellRow, _TableCellLayout)> contentRows({
    bool includeTables = false,
  }) {
    final generation = (host.layoutGeneration, host.codeOffsetGeneration);
    if (_contentGeneration != generation) {
      _contentGeneration = generation;
      _contentRows.clear();
    }
    return _contentRows.putIfAbsent(includeTables, () {
      return _collectContentRows(includeTables: includeTables)
          .toList(growable: false);
    });
  }

  Iterable<(_CellRow, _TableCellLayout)> _collectContentRows({
    required bool includeTables,
  }) sync* {
    for (final cell in cells) {
      for (final block in cell.blocks) {
        block.scrollOffset = host.codeOffset(block);
        if (block.layout case final _TableRowLayout nested) {
          if (includeTables) {
            yield (
              block.shifted(0, _blockOrigin(cell, Offset.zero), cell.rect),
              cell,
            );
          }
          final offset = _textOrigin(cell, block);
          for (final (child, _) in nested.contentRows(
            includeTables: includeTables,
          )) {
            yield (child.shifted(block.position, offset, cell.rect), cell);
          }
        } else {
          yield (
            block.shifted(0, _blockOrigin(cell, Offset.zero), cell.rect),
            cell,
          );
        }
      }
    }
  }

  _CellRow? contentAt(int position) {
    for (final (block, _) in contentRows()) {
      if (position >= block.position &&
          position < block.position + block.layout.node.nodeSize) {
        return block;
      }
    }
    return null;
  }

  Rect? nestedCellRect(int position) {
    for (final cell in cells) {
      if (position == cell.position) {
        final top = cell.continuation;
        final extent = geometry.spans
            ? geometry.offsets[cell.grid.bottom] -
                  geometry.offsets[cell.grid.top]
            : height;
        return Rect.fromLTWH(cell.rect.left, -top, cell.rect.width, extent);
      }
      for (final block in cell.blocks) {
        if (block.layout case final _TableRowLayout nested) {
          final rect = nested.nestedCellRect(position - block.position);
          if (rect != null) return rect.shift(_textOrigin(cell, block));
        }
      }
    }
    return null;
  }

  (_CellRow, _TableCellLayout)? _block(int position) {
    (_CellRow, _TableCellLayout)? best;
    for (final cell in cells) {
      for (final block in cell.blocks) {
        if (position >= block.position &&
            position < block.position + block.layout.node.nodeSize) {
          return (block, cell);
        }
        if (best == null ||
            block.position <= position && block.position > best.$1.position) {
          best = (block, cell);
        }
      }
    }
    return best;
  }

  T? _inBlock<T>(
    int offset,
    T Function(_CellRow block, int local, Offset origin) build,
  ) {
    final found = _block(offset + 1);
    if (found == null) return null;
    final (block, cell) = found;
    return build(
      block,
      (offset - block.position).clamp(0, block.layout.node.content.size),
      _textOrigin(cell, block),
    );
  }

  @override
  _CaretGeometry caretGeometry(int offset, double width, double factor) =>
      _inBlock(
        offset,
        (block, local, origin) =>
            block.layout.caretGeometry(local, width, factor).shift(origin),
      ) ??
      _CaretGeometry(Rect.fromLTWH(0, 0, width, 24), 18, 18, 6);

  @override
  Rect caret(int offset, double caretWidth) =>
      _inBlock(
        offset,
        (block, local, origin) =>
            block.layout.caret(local, caretWidth).shift(origin),
      ) ??
      Rect.fromLTWH(0, 0, caretWidth, 24);

  @override
  int position(Offset offset) {
    if (cells.isEmpty) return 0;
    final cell = cells.firstWhere(
      (cell) => offset.dx < cell.rect.right,
      orElse: () => cells.last,
    );
    if (cell.blocks.isEmpty) return cell.position;
    var block = cell.blocks.last;
    for (final candidate in cell.blocks) {
      if (offset.dy <
          _blockOrigin(cell, candidate.origin).dy + candidate.height) {
        block = candidate;
        break;
      }
    }
    final node = block.layout.node;
    if (node.isLeaf) return block.position - 1;
    return block.position +
        block.layout
            .position(offset - _textOrigin(cell, block))
            .clamp(0, node.content.size);
  }

  @override
  List<Rect> boxes(int from, int to) {
    final result = <Rect>[];
    for (final cell in cells) {
      for (final block in cell.blocks) {
        final node = block.layout.node;
        final clip = block.row.node.type == 'codeBlock'
            ? block.rect
                  .deflate(12)
                  .shift(_blockOrigin(cell, Offset.zero))
                  .intersect(cell.rect)
            : cell.rect;
        if (node.isLeaf) {
          if (from < block.position && to >= block.position) {
            result.add(
              block.rect.shift(_blockOrigin(cell, Offset.zero)).intersect(clip),
            );
          }
        } else {
          result.addAll(
            block.layout
                .boxes(from - block.position, to - block.position)
                .map(
                  (rect) =>
                      rect.shift(_textOrigin(cell, block)).intersect(clip),
                )
                .where((rect) => !rect.isEmpty),
          );
        }
      }
    }
    return result;
  }

  @override
  TextRange boundary(int offset, {required bool word}) {
    final found = _block(offset + 1);
    if (found == null) return const TextRange.collapsed(0);
    final block = found.$1;
    if (block.layout.node.isLeaf) {
      return TextRange(start: block.position - 1, end: block.position);
    }
    final range = block.layout.boundary(
      (offset - block.position).clamp(0, block.layout.node.content.size),
      word: word,
    );
    return TextRange(
      start: range.start + block.position,
      end: range.end + block.position,
    );
  }

  void paint(
    Canvas canvas,
    Offset origin,
    TiptapEditorStyle style, {
    required bool background,
    required void Function(_CellRow row, Offset card, Offset text, _Row? next)
    paintRow,
  }) {
    canvas.save();
    canvas.clipRect(origin & Size(tableWidth, height));
    for (final cell in cells) {
      final rect = cell.rect.shift(origin);
      if (background) {
        if (cell.node.type == 'tableHeader') {
          canvas.drawRect(rect, Paint()..color = style.codeBackground);
        }
        final border = Paint()
          ..color = style.opaqueBorder
          ..strokeWidth = 1;
        final left = rect.left + (cell.grid.left == 0 ? .5 : 0);
        final right =
            rect.right -
            (cell.grid.right == m.TableMap.get(table).width ? .5 : 0);
        canvas.drawLine(
          Offset(left, rect.top),
          Offset(left, rect.bottom),
          border,
        );
        canvas.drawLine(
          Offset(right, rect.top),
          Offset(right, rect.bottom),
          border,
        );
        if (cell.grid.top == rowIndex) {
          final top = rect.top + (cell.grid.top == 0 ? .5 : 0);
          canvas.drawLine(
            Offset(rect.left, top),
            Offset(rect.right, top),
            border,
          );
        }
        if (cell.grid.bottom == rowIndex + 1) {
          final bottom =
              rect.bottom - (cell.grid.bottom == table.childCount ? .5 : 0);
          canvas.drawLine(
            Offset(rect.left, bottom),
            Offset(rect.right, bottom),
            border,
          );
        }
      }
      canvas.save();
      canvas.clipRect(rect);
      for (var index = 0; index < cell.blocks.length; index++) {
        final block = cell.blocks[index];
        paintRow(
          block,
          origin + _blockOrigin(cell, block.origin),
          origin + _textOrigin(cell, block),
          index + 1 < cell.blocks.length ? cell.blocks[index + 1].row : null,
        );
        if (block.layout case final _TableRowLayout nested) {
          nested.paint(
            canvas,
            origin + _textOrigin(cell, block),
            style,
            background: background,
            paintRow: (child, card, text, next) => paintRow(
              child.shifted(block.position, Offset.zero, cell.rect),
              card,
              text,
              next,
            ),
          );
        }
      }
      canvas.restore();
    }
    canvas.restore();
  }
}
