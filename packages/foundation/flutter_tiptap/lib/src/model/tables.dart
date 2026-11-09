part of '../model.dart';

class CellRect {
  const CellRect(this.left, this.top, this.right, this.bottom);
  final int left, top, right, bottom;
}

/// Identity-cached ProseMirror table grid. Offsets are relative to table content.
class TableMap {
  TableMap._(
    this.width,
    this.height,
    this.map,
    this.problems,
    this.hasColwidth,
  ) {
    for (var i = 0; i < map.length; i++) {
      final pos = map[i];
      if (pos == 0 || _rects.containsKey(pos)) continue;
      final left = i % width, top = i ~/ width;
      var right = left + 1, bottom = top + 1;
      while (right < width && map[top * width + right] == pos) {
        right++;
      }
      while (bottom < height && map[bottom * width + left] == pos) {
        bottom++;
      }
      _rects[pos] = CellRect(left, top, right, bottom);
    }
  }
  final int width, height;
  final bool hasColwidth;
  late final bool hasRowspan = _rects.values.any((r) => r.bottom - r.top > 1);
  final List<int> map;
  final List<Map<String, Object>> problems;
  static final Expando<TableMap> _cache = Expando<TableMap>();
  static TableMap get(Node table) => _cache[table] ??= _compute(table);
  static TableMap _compute(Node table) {
    if (table.type != 'table') throw ArgumentError('Expected table');
    var width = 0, activeWidth = 0;
    final ends = <int, int>{};
    // The sum of all active earlier rowspans, kept by an expiry index rather
    // than rescanning preceding rows in a tall table.
    for (var row = 0; row < table.childCount; row++) {
      activeWidth -= ends[row] ?? 0;
      var rowWidth = activeWidth;
      for (final cell in table.child(row).content) {
        final cols = _span(cell, 'colspan'), rows = _span(cell, 'rowspan');
        rowWidth += cols;
        if (rows > 1) {
          activeWidth += cols;
          ends.update(row + rows, (v) => v + cols, ifAbsent: () => cols);
        }
      }
      width = math.max(width, rowWidth);
    }
    final height = table.childCount,
        grid = List.filled(width * height, 0),
        problems = <Map<String, Object>>[];
    final colWidths = List<int?>.filled(width, null),
        counts = List.filled(width, 0);
    var mapPos = 0, hasColwidth = false;
    for (var row = 0, pos = 0; row < height; row++) {
      final rowNode = table.child(row);
      pos++;
      for (var c = 0; ; c++) {
        while (mapPos < grid.length && grid[mapPos] != 0) {
          mapPos++;
        }
        if (c == rowNode.childCount) break;
        final cell = rowNode.child(c),
            cols = _span(cell, 'colspan'),
            rows = _span(cell, 'rowspan'),
            values = cell.attrs['colwidth'];
        hasColwidth |= values is List;
        for (var h = 0; h < rows; h++) {
          if (row + h >= height) {
            problems.add({
              'type': 'overlong_rowspan',
              'pos': pos,
              'n': rows - h,
            });
            break;
          }
          final start = mapPos + h * width;
          for (var w = 0; w < cols; w++) {
            final index = start + w;
            if (index < grid.length && grid[index] == 0) {
              grid[index] = pos;
            } else {
              problems.add({
                'type': 'collision',
                'row': row,
                'pos': pos,
                'n': cols - w,
              });
            }
            final value = values is List && w < values.length
                ? values[w]
                : null;
            if (value is int && value > 0 && width > 0) {
              final col = index % width;
              if (colWidths[col] == null ||
                  colWidths[col] != value && counts[col] == 1) {
                colWidths[col] = value;
                counts[col] = 1;
              } else if (colWidths[col] == value) {
                counts[col]++;
              }
            }
          }
        }
        mapPos += cols;
        pos += cell.nodeSize;
      }
      var missing = 0;
      while (mapPos < (row + 1) * width) {
        if (grid[mapPos++] == 0) missing++;
      }
      if (missing > 0) {
        problems.add({'type': 'missing', 'row': row, 'n': missing});
      }
      pos++;
    }
    if (width == 0 || height == 0) problems.add({'type': 'zero_sized'});
    if (List.generate(
      width,
      (c) => colWidths[c] != null && counts[c] < height,
    ).any((v) => v)) {
      final seen = <int>{};
      for (var i = 0; i < grid.length; i++) {
        final pos = grid[i];
        if (pos == 0 || !seen.add(pos)) continue;
        final cell = table.nodeAt(pos)!,
            span = _span(cell, 'colspan'),
            values = cell.attrs['colwidth'];
        final next = values is List
            ? List<Object?>.of(values)
            : List<Object?>.filled(span, 0);
        var changed = false;
        for (var c = 0; c < span; c++) {
          final value = colWidths[(i + c) % width];
          if (value != null && next[c] != value) {
            next[c] = value;
            changed = true;
          }
        }
        if (changed) {
          problems.insert(0, {
            'type': 'colwidth mismatch',
            'pos': pos,
            'colwidth': next,
          });
        }
      }
    }
    return TableMap._(
      width,
      height,
      List.unmodifiable(grid),
      List.unmodifiable(problems),
      hasColwidth,
    );
  }

  final Map<int, CellRect> _rects = {};
  CellRect findCell(int pos) {
    if (_rects[pos] case final rect?) return rect;
    final index = map.indexOf(pos);
    if (index < 0) throw RangeError('No cell at $pos');
    final left = index % width, top = index ~/ width;
    var right = left + 1, bottom = top + 1;
    while (right < width && map[top * width + right] == pos) {
      right++;
    }
    while (bottom < height && map[bottom * width + left] == pos) {
      bottom++;
    }
    return _rects[pos] = CellRect(left, top, right, bottom);
  }

  int colCount(int pos) => findCell(pos).left;
  CellRect rectBetween(int a, int b) {
    final x = findCell(a), y = findCell(b);
    return CellRect(
      math.min(x.left, y.left),
      math.min(x.top, y.top),
      math.max(x.right, y.right),
      math.max(x.bottom, y.bottom),
    );
  }

  List<int> cellsInRect(CellRect rect) {
    final seen = <int>{}, result = <int>[];
    for (var r = rect.top; r < rect.bottom; r++) {
      for (var c = rect.left; c < rect.right; c++) {
        final i = r * width + c, pos = map[i];
        if (!seen.add(pos) || pos == 0) continue;
        if (c == rect.left && c > 0 && map[i - 1] == pos ||
            r == rect.top && r > 0 && map[i - width] == pos) {
          continue;
        }
        result.add(pos);
      }
    }
    return result;
  }

  int? nextCell(int pos, String axis, int direction) {
    final rect = findCell(pos);
    final r = axis == 'horiz'
        ? rect.top
        : direction < 0
        ? rect.top - 1
        : rect.bottom;
    final c = axis == 'horiz'
        ? direction < 0
              ? rect.left - 1
              : rect.right
        : rect.left;
    return r < 0 || r >= height || c < 0 || c >= width
        ? null
        : map[r * width + c];
  }

  int positionAt(int row, int col, Node table) {
    final start = table.content.positionAt(row),
        end = start + table.child(row).nodeSize;
    var i = row * width + col;
    while (i < (row + 1) * width && map[i] < start) {
      i++;
    }
    return i == (row + 1) * width ? end - 1 : map[i];
  }
}

int _span(Node cell, String attr) =>
    math.max(1, (cell.attrs[attr] as num? ?? 1).toInt());
bool _isCell(Node node) =>
    node.type == 'tableCell' || node.type == 'tableHeader';

class TableContext {
  const TableContext(
    this.table,
    this.tablePosition,
    this.cell,
    this.cellPosition,
  );
  final Node table, cell;
  final int tablePosition, cellPosition;
  int get tableStart => tablePosition + 1;
  TableMap get map => TableMap.get(table);
  CellRect get rect => map.findCell(cellPosition - tableStart);
}

TableContext? tableContext(Node doc, int position) {
  final pos = doc.resolve(position);
  for (var d = pos.depth; d > 0; d--) {
    if (_isCell(pos.node(d))) {
      return TableContext(
        pos.node(d - 2),
        pos.before(d - 2),
        pos.node(d),
        pos.before(d),
      );
    }
  }
  if (_isCell(pos.nodeAfter ?? doc)) {
    return TableContext(
      pos.node(pos.depth - 1),
      pos.before(pos.depth - 1),
      pos.nodeAfter!,
      position,
    );
  }
  return null;
}

class CellSelection extends Selection {
  CellSelection(Node doc, this.anchorCell, [int? headCell])
    : headCell = headCell ?? anchorCell,
      super(
        (headCell ?? anchorCell) + 1,
        (headCell ?? anchorCell) +
            doc.nodeAt(headCell ?? anchorCell)!.nodeSize -
            1,
      ) {
    final context = tableContext(doc, anchorCell)!;
    tablePosition = context.tablePosition;
    _table = context.table;
    rect = context.map.rectBetween(
      anchorCell - context.tableStart,
      this.headCell - context.tableStart,
    );
    cells = List.unmodifiable(
      context.map.cellsInRect(rect).map((p) => p + context.tableStart),
    );
  }
  final int anchorCell, headCell;
  late final int tablePosition;
  late final Node _table;
  bool get isRowSelection =>
      rect.left == 0 && rect.right == TableMap.get(_table).width;
  bool get isColumnSelection =>
      rect.top == 0 && rect.bottom == TableMap.get(_table).height;
  late final CellRect rect;
  late final List<int> cells;
  factory CellSelection.row(Node doc, int anchor, [int? head]) {
    head ??= anchor;
    final c = tableContext(doc, anchor)!,
        map = c.map,
        a = map.findCell(anchor - c.tableStart),
        b = map.findCell(head - c.tableStart);
    if (a.left <= b.left) {
      if (a.left > 0) anchor = c.tableStart + map.map[a.top * map.width];
      if (b.right < map.width) {
        head = c.tableStart + map.map[map.width * (b.top + 1) - 1];
      }
    } else {
      if (b.left > 0) head = c.tableStart + map.map[b.top * map.width];
      if (a.right < map.width) {
        anchor = c.tableStart + map.map[map.width * (a.top + 1) - 1];
      }
    }
    return CellSelection(doc, anchor, head);
  }
  factory CellSelection.column(Node doc, int anchor, [int? head]) {
    head ??= anchor;
    final c = tableContext(doc, anchor)!,
        map = c.map,
        a = map.findCell(anchor - c.tableStart),
        b = map.findCell(head - c.tableStart);
    if (a.top <= b.top) {
      if (a.top > 0) anchor = c.tableStart + map.map[a.left];
      if (b.bottom < map.height) {
        head =
            c.tableStart + map.map[map.width * (map.height - 1) + b.right - 1];
      }
    } else {
      if (b.top > 0) head = c.tableStart + map.map[b.left];
      if (a.bottom < map.height) {
        anchor =
            c.tableStart + map.map[map.width * (map.height - 1) + a.right - 1];
      }
    }
    return CellSelection(doc, anchor, head);
  }
  Slice content(Node doc) {
    final context = tableContext(doc, anchorCell)!,
        table = context.table,
        map = context.map,
        seen = <int>{},
        rows = <Node>[];
    for (var row = rect.top; row < rect.bottom; row++) {
      final cells = <Node>[];
      for (var col = rect.left; col < rect.right; col++) {
        final p = map.map[row * map.width + col];
        if (!seen.add(p)) continue;
        var cell = table.nodeAt(p)!;
        final bounds = map.findCell(p);
        final left = math.max(rect.left, bounds.left),
            right = math.min(rect.right, bounds.right);
        final top = math.max(rect.top, bounds.top),
            bottom = math.min(rect.bottom, bounds.bottom);
        final attrs = {
          ...cell.attrs,
          'colspan': right - left,
          'rowspan': bottom - top,
        };
        if (cell.attrs['colwidth'] case final List widths) {
          attrs['colwidth'] = widths
              .skip(left - bounds.left)
              .take(right - left)
              .toList();
        }
        cell = cell.withAttrs(attrs);
        if (bounds.left < rect.left || bounds.top < rect.top) {
          cell = cell.copy(Fragment([doc.schema.node('paragraph')]));
        }
        cells.add(cell);
      }
      rows.add(table.child(row).copy(Fragment.blocks(cells)));
    }
    return Slice(
      Fragment(
        rect.left == 0 &&
                rect.right == map.width &&
                rect.top == 0 &&
                rect.bottom == map.height
            ? [table.copy(Fragment.blocks(rows))]
            : rows,
      ),
      1,
      1,
    );
  }

  @override
  bool get empty => false;
  @override
  Selection map(Node doc, Mapping mapping) {
    final a = mapping.map(anchorCell), b = mapping.map(headCell);
    if (_isCell(doc.nodeAt(a) ?? doc) &&
        _isCell(doc.nodeAt(b) ?? doc) &&
        tableContext(doc, a)?.tablePosition ==
            tableContext(doc, b)?.tablePosition) {
      final table = tableContext(doc, a)!.table;
      if (!identical(table, _table)) {
        if (isRowSelection) return CellSelection.row(doc, a, b);
        if (isColumnSelection) return CellSelection.column(doc, a, b);
      }
      return CellSelection(doc, a, b);
    }
    return Selection.near(doc, mapping.map(head).clamp(0, doc.content.size));
  }

  @override
  bool operator ==(Object other) =>
      other is CellSelection &&
      anchorCell == other.anchorCell &&
      headCell == other.headCell;
  @override
  int get hashCode => Object.hash(anchorCell, headCell);
}

Selection _normalizeTableSelection(Node doc, Selection selection) {
  if (selection is NodeSelection) {
    final node = doc.nodeAt(selection.from)!;
    if (_isCell(node)) return CellSelection(doc, selection.from);
    if (node.type == 'tableRow' && node.childCount > 0) {
      return CellSelection.row(doc, selection.from + 1);
    }
    if (node.type == 'table') {
      final map = TableMap.get(node);
      if (map.map.isNotEmpty) {
        return CellSelection(
          doc,
          selection.from + 1 + map.map.first,
          selection.from + 1 + map.map.last,
        );
      }
    }
  }
  return selection;
}

Node createTable(
  Schema schema, {
  int rows = 3,
  int columns = 3,
  bool withHeaderRow = true,
}) => schema.node(
  'table',
  content: [
    for (var r = 0; r < rows; r++)
      schema.node(
        'tableRow',
        content: [
          for (var c = 0; c < columns; c++)
            schema.createAndFill(
              r == 0 && withHeaderRow ? 'tableHeader' : 'tableCell',
            )!,
        ],
      ),
  ],
);

final Expando<Node> _fixedTables = Expando<Node>();

/// Repairs malformed grids and inconsistent column widths. Valid subtrees retain
/// identity; normalization never flattens a merged cell's content.
Node fixTables(Node doc) => _fixedTables[doc] ??= _fixTables(doc);
Node _fixTables(Node node) {
  if (node.isLeaf || node.isTextblock) return node;
  final children = node.content
      .where(
        (child) =>
            child.type != 'table' ||
            TableMap.get(child).width > 0 && child.childCount > 0,
      )
      .map(fixTables)
      .toList();
  if (children.isEmpty &&
      node.childCount > 0 &&
      const {
        'doc',
        'tableCell',
        'tableHeader',
        'blockquote',
      }.contains(node.type)) {
    children.add(node.schema.node('paragraph'));
  }
  if (node.type == 'table') {
    final original = node.copy(Fragment.blocks(children)),
        map = TableMap.get(original);
    if (map.problems.isEmpty) {
      return List.generate(
            children.length,
            (i) => identical(children[i], node.child(i)),
          ).every((v) => v)
          ? node
          : original;
    }
    final mustAdd = List.filled(map.height, 0);
    final attrs = <int, Map<String, Object?>>{};
    for (final problem in map.problems) {
      final type = problem['type'];
      if (type == 'missing') {
        mustAdd[problem['row']! as int] += problem['n']! as int;
      } else if (type == 'colwidth mismatch') {
        final p = problem['pos']! as int;
        attrs[p] = {
          ...original.nodeAt(p)!.attrs,
          'colwidth': problem['colwidth'],
        };
      } else if (type == 'overlong_rowspan' || type == 'collision') {
        final p = problem['pos']! as int,
            cell = original.nodeAt(p)!,
            n = problem['n']! as int;
        final next = attrs[p] = Map.of(cell.attrs);
        if (type == 'overlong_rowspan') {
          next['rowspan'] = _span(cell, 'rowspan') - n;
        } else {
          next['colspan'] = math.max(1, _span(cell, 'colspan') - n);
          if (next['colwidth'] case final List widths) {
            final remaining = widths.take(next['colspan']! as int).toList();
            next['colwidth'] = remaining.any((v) => v != 0) ? remaining : null;
          }
          for (
            var r = problem['row']! as int;
            r <
                math.min(
                  map.height,
                  (problem['row']! as int) + _span(cell, 'rowspan'),
                );
            r++
          ) {
            mustAdd[r] += n;
          }
        }
      }
    }
    final first = mustAdd.indexWhere((v) => v > 0),
        last = mustAdd.lastIndexWhere((v) => v > 0);
    for (var r = 0; r < children.length; r++) {
      final row = children[r], cells = <Node>[];
      for (var c = 0; c < row.childCount; c++) {
        final p =
                original.content.positionAt(r) + 1 + row.content.positionAt(c),
            cell = row.child(c);
        cells.add(attrs[p] == null ? cell : cell.withAttrs(attrs[p]!));
      }
      final added = [
        for (var n = 0; n < mustAdd[r]; n++)
          node.schema.createAndFill(cells.firstOrNull?.type ?? 'tableCell')!,
      ];
      if ((r == 0 || first == r - 1) && last == r) {
        cells.insertAll(0, added);
      } else {
        cells.addAll(added);
      }
      children[r] =
          cells.length == row.childCount &&
              List.generate(
                cells.length,
                (i) => identical(cells[i], row.child(i)),
              ).every((v) => v)
          ? row
          : row.copy(Fragment.blocks(cells));
    }
  }
  return List.generate(
        children.length,
        (i) => identical(children[i], node.child(i)),
      ).every((v) => v)
      ? node
      : node.copy(Fragment.blocks(children));
}

extension on EditorCommands {
  bool _tableCommand(Transaction tr, String name, Map<String, dynamic> args) {
    final schema = tr.doc.schema;
    if (name == 'insertTable') {
      final table = createTable(
        schema,
        rows: args['rows'] as int? ?? 3,
        columns: args['cols'] as int? ?? 3,
        withHeaderRow: args['withHeaderRow'] != false,
      );
      final before = tr.selection.from;
      final resolved = tr.doc.resolve(tr.selection.from);
      final empty =
          resolved.parent.isTextblock && resolved.parent.content.isEmpty;
      tr.replace(
        empty ? resolved.before() : tr.selection.from,
        empty ? resolved.after() : tr.selection.to,
        Slice(Fragment([table]), 0, 0),
      );
      var p = tr.mapping.map(before, -1);
      while (p < tr.doc.content.size && tr.doc.nodeAt(p)?.type != 'table') {
        p++;
      }
      if (p < tr.doc.content.size) {
        if (trailingParagraph && p + table.nodeSize == tr.doc.content.size) {
          final end = tr.doc.content.size;
          tr.replace(
            end,
            end,
            Slice(Fragment([schema.node('paragraph')]), 0, 0),
          );
        }
        tr.setSelection(Selection.near(tr.doc, p + 1));
      }
      return true;
    }
    if (name == 'fixTables') {
      final doc = fixTables(tr.doc);
      if (!identical(doc, tr.doc)) {
        tr.replace(0, tr.doc.content.size, Slice(doc.content, 0, 0));
      }
      return true;
    }
    if (!const {
          'setCellSelection',
          'selectTableRow',
          'selectTableColumn',
          'deleteTable',
          'tab',
          'shiftTab',
          'goToNextCell',
          'goToPreviousCell',
          'addRowBefore',
          'addRowAfter',
          'addColumnBefore',
          'addColumnAfter',
          'deleteRow',
          'deleteColumn',
          'toggleHeaderRow',
          'mergeCells',
          'splitCell',
          'arrowDown',
          'arrowUp',
          'arrowLeft',
          'arrowRight',
          'splitBlock',
        }.contains(name) &&
        !(tr.selection is CellSelection &&
            (name == 'deleteBackward' || name == 'deleteForward'))) {
      return false;
    }
    final context = tableContext(tr.doc, tr.selection.head);
    if (context == null) return false;
    final table = context.table, map = context.map, start = context.tableStart;
    final selection = tr.selection;
    final rect = selection is CellSelection ? selection.rect : context.rect;
    void markup(int pos, Node cell) =>
        tr.step(_SetNodeStep(tr.mapping.map(start + pos), cell));
    if (name == 'setCellSelection' ||
        name == 'selectTableRow' ||
        name == 'selectTableColumn') {
      final cell = args['anchorCell'] as int? ?? context.cellPosition;
      tr.setSelection(
        name == 'selectTableRow'
            ? CellSelection.row(tr.doc, cell)
            : name == 'selectTableColumn'
            ? CellSelection.column(tr.doc, cell)
            : CellSelection(tr.doc, cell, args['headCell'] as int?),
      );
      return true;
    }
    if ((name == 'deleteBackward' || name == 'deleteForward') &&
        selection is CellSelection) {
      if (rect.left == 0 &&
          rect.top == 0 &&
          rect.right == map.width &&
          rect.bottom == map.height) {
        tr.replace(start - 1, start + table.nodeSize - 1);
        tr.setSelection(
          Selection.near(tr.doc, (start - 1).clamp(0, tr.doc.content.size)),
        );
        return true;
      }

      for (final cell in selection.cells.reversed) {
        final node = tr.doc.nodeAt(cell)!;
        tr.replace(
          cell + 1,
          cell + node.nodeSize - 1,
          Slice(Fragment([schema.node('paragraph')]), 0, 0),
        );
      }
      return true;
    }
    if (const {
      'arrowDown',
      'arrowUp',
      'arrowLeft',
      'arrowRight',
    }.contains(name)) {
      final direction = name == 'arrowUp' || name == 'arrowLeft' ? -1 : 1,
          axis = name == 'arrowLeft' || name == 'arrowRight' ? 'horiz' : 'vert';
      final next = map.nextCell(context.cellPosition - start, axis, direction);
      if (args['extend'] == true) {
        if (next != null) {
          tr.setSelection(
            CellSelection(
              tr.doc,
              selection is CellSelection
                  ? selection.anchorCell
                  : context.cellPosition,
              start + next,
            ),
          );
        }
      } else if (selection is CellSelection) {
        tr.setSelection(
          Selection.near(tr.doc, selection.headCell, bias: direction),
        );
      } else if (direction < 0 &&
          context.tablePosition == 0 &&
          (axis == 'vert' && next == null ||
              axis == 'horiz' &&
                  context.rect.top == 0 &&
                  context.rect.left == 0)) {
        tr.setSelection(const GapSelection(0));
      } else if (axis == 'horiz') {
        tr.setSelection(
          Selection.near(
            tr.doc,
            (selection.head + direction).clamp(0, tr.doc.content.size),
            bias: direction,
          ),
        );
      } else {
        tr.setSelection(
          Selection.near(
            tr.doc,
            next == null
                ? (direction > 0 ? start + table.nodeSize - 1 : start - 1)
                : start + next + 1,
            bias: next == null ? direction : 1,
          ),
        );
      }
      return true;
    }
    if (name == 'splitBlock' && selection is CellSelection) {
      tr.setSelection(Selection.near(tr.doc, selection.head, bias: -1));
      this._split(EditorState(doc: tr.doc, selection: tr.selection), tr);
      return true;
    }
    if (name == 'deleteTable') {
      tr.replace(start - 1, start + table.nodeSize - 1);
      tr.setSelection(
        Selection.near(tr.doc, (start - 1).clamp(0, tr.doc.content.size)),
      );
      return true;
    }
    if (name == 'tab' ||
        name == 'shiftTab' ||
        name == 'goToNextCell' ||
        name == 'goToPreviousCell') {
      final direction = name == 'shiftTab' || name == 'goToPreviousCell'
          ? -1
          : args['direction'] as int? ?? 1;
      final cells = <int>[];
      for (var r = 0; r < table.childCount; r++) {
        final row = table.child(r), p = table.content.positionAt(r) + 1;
        for (var c = 0; c < row.childCount; c++) {
          cells.add(start + p + row.content.positionAt(c));
        }
      }
      final index = cells.indexOf(context.cellPosition) + direction;
      if (index >= 0 && index < cells.length) {
        final p = cells[index], node = tr.doc.nodeAt(p)!;
        tr.setSelection(TextSelection(p + 2, p + node.nodeSize - 2));
      } else if (direction > 0 && name == 'tab') {
        _tableAddRow(tr, context, map.height);
        final next = tableContext(tr.doc, tr.selection.head) ?? context;
        final updated = tr.doc.nodeAt(start - 1)!,
            p = start + updated.content.positionAt(updated.childCount - 1) + 1;
        tr.setSelection(TextSelection(p + 2));
        // Keep selection in the new row, not the table's trailing paragraph.
        assert(next.tablePosition == context.tablePosition);
      }
      return true;
    }
    if (name == 'mergeCells') {
      if (selection is! CellSelection ||
          selection.anchorCell == selection.headCell) {
        return true;
      }
      final positions = map.cellsInRect(rect);
      // A spanning cell crossing the rectangle makes merging invalid.
      for (final p in map.map.toSet()) {
        final cellRect = map.findCell(p);
        if (cellRect.right > rect.left &&
            cellRect.left < rect.right &&
            cellRect.bottom > rect.top &&
            cellRect.top < rect.bottom &&
            (cellRect.left < rect.left ||
                cellRect.right > rect.right ||
                cellRect.top < rect.top ||
                cellRect.bottom > rect.bottom)) {
          return true;
        }
      }
      if (positions.isEmpty) return true;
      final first = positions.first, cell = table.nodeAt(first)!;
      bool empty(Node cell) =>
          cell.childCount == 1 &&
          cell.child(0).isTextblock &&
          cell.child(0).content.isEmpty;
      var content = Fragment.empty;
      for (final p in positions.skip(1)) {
        final other = table.nodeAt(p)!;
        if (!empty(other)) content = content.append(other.content);
        final at = tr.mapping.map(start + p);
        tr.replace(at, at + other.nodeSize);
      }
      final span = rect.right - rect.left, widths = cell.attrs['colwidth'];
      final attrs = {
        ...cell.attrs,
        'colspan': span,
        'rowspan': rect.bottom - rect.top,
        if (widths is List)
          'colwidth': [...widths, ...List.filled(span - widths.length, 0)],
      };
      tr.step(_SetNodeStep(start + first, cell.withAttrs(attrs)));
      if (content.isNotEmpty) {
        final end = start + first + 1 + cell.content.size;
        tr.replace(
          empty(cell) ? start + first + 1 : end,
          end,
          Slice(content, 0, 0),
        );
      }
      tr.setSelection(CellSelection(tr.doc, start + first));
      return true;
    }
    if (name == 'splitCell') {
      if (selection is CellSelection &&
          selection.anchorCell != selection.headCell) {
        return true;
      }
      final cell = context.cell;
      if (_span(cell, 'colspan') == 1 && _span(cell, 'rowspan') == 1) {
        return true;
      }
      final widths = cell.attrs['colwidth'];
      Map<String, Object?> attrs(int c) => {
        ...cell.attrs,
        'rowspan': 1,
        'colspan': 1,
        'colwidth': widths is List && widths[c] != 0 ? [widths[c]] : null,
      };
      int? last;
      for (var r = rect.top; r < rect.bottom; r++) {
        var pos = map.positionAt(r, rect.left, table);
        if (r == rect.top) pos += cell.nodeSize;
        for (var c = rect.left; c < rect.right; c++) {
          if (r == rect.top && c == rect.left) continue;
          last = tr.mapping.map(start + pos);
          tr.replace(
            last,
            last,
            Slice(
              Fragment([
                schema.createAndFill(cell.type, attrs: attrs(c - rect.left))!,
              ]),
              0,
              0,
            ),
          );
        }
      }
      tr.step(_SetNodeStep(context.cellPosition, cell.withAttrs(attrs(0))));
      if (selection is CellSelection) {
        tr.setSelection(CellSelection(tr.doc, context.cellPosition, last));
      }
      return true;
    }
    if (name == 'addRowBefore' || name == 'addRowAfter') {
      _tableAddRow(
        tr,
        context,
        name == 'addRowBefore' ? rect.top : rect.bottom,
      );
      return true;
    }
    if (name == 'addColumnBefore' || name == 'addColumnAfter') {
      final col = name == 'addColumnBefore' ? rect.left : rect.right;
      final ref = col > 0 ? -1 : 0;
      final header = List.generate(
        map.height,
        (r) =>
            table.nodeAt(map.map[r * map.width + col + ref])!.type ==
            'tableHeader',
      ).every((v) => v);
      final int? reference = header
          ? (col == 0 || col == map.width ? null : 0)
          : ref;
      for (var r = 0; r < map.height; r++) {
        final i = r * map.width + col;
        if (col > 0 && col < map.width && map.map[i - 1] == map.map[i]) {
          final p = map.map[i],
              cell = table.nodeAt(p)!,
              attrs = {...cell.attrs, 'colspan': _span(cell, 'colspan') + 1};
          if (cell.attrs['colwidth'] case final List widths) {
            final next = List<Object?>.of(widths)
              ..insert(col - map.colCount(p), 0);
            attrs['colwidth'] = next;
          }
          markup(p, cell.withAttrs(attrs));
          r += _span(cell, 'rowspan') - 1;
        } else {
          final type = reference == null
              ? 'tableCell'
              : table.nodeAt(map.map[i + reference])!.type;
          final p = tr.mapping.map(start + map.positionAt(r, col, table));
          tr.replace(
            p,
            p,
            Slice(Fragment([schema.createAndFill(type)!]), 0, 0),
          );
        }
      }
      return true;
    }
    if (name == 'deleteRow') {
      if (rect.top == 0 && rect.bottom == map.height) return true;
      for (var r = rect.bottom - 1; r >= rect.top; r--) {
        final current = tr.doc.nodeAt(start - 1)!,
            grid = TableMap.get(current),
            rowPos = current.content.positionAt(r),
            row = current.child(r);
        final stepCount = tr.mapping.maps.length;
        tr.replace(start + rowPos, start + rowPos + row.nodeSize);
        int mapped(int p) =>
            Mapping(tr.mapping.maps.skip(stepCount)).map(start + p);
        final seen = <int>{};
        for (var c = 0; c < grid.width; c++) {
          final p = grid.map[r * grid.width + c];
          if (!seen.add(p)) continue;
          final cell = current.nodeAt(p)!;
          if (r > 0 && grid.map[(r - 1) * grid.width + c] == p) {
            tr.step(AttrStep(mapped(p), 'rowspan', _span(cell, 'rowspan') - 1));
          } else if (r + 1 < grid.height &&
              grid.map[(r + 1) * grid.width + c] == p) {
            final dest = mapped(grid.positionAt(r + 1, c, current));
            tr.replace(
              dest,
              dest,
              Slice(
                Fragment([
                  cell.withAttrs({
                    ...cell.attrs,
                    'rowspan': _span(cell, 'rowspan') - 1,
                  }),
                ]),
                0,
                0,
              ),
            );
          }
        }
      }
      if (tableContext(tr.doc, tr.selection.head)?.tablePosition != start - 1) {
        final current = tr.doc.nodeAt(start - 1)!;
        tr.setSelection(
          Selection.near(tr.doc, start + current.nodeSize - 2, bias: -1),
        );
      } else {
        tr.setSelection(Selection.near(tr.doc, tr.selection.head));
      }
      return true;
    }
    if (name == 'deleteColumn') {
      if (rect.left == 0 && rect.right == map.width) return true;
      for (var c = rect.right - 1; c >= rect.left; c--) {
        final current = tr.doc.nodeAt(start - 1)!,
            grid = TableMap.get(current),
            stepCount = tr.mapping.maps.length;
        int mapped(int p) =>
            Mapping(tr.mapping.maps.skip(stepCount)).map(start + p);
        for (var r = 0; r < grid.height;) {
          final p = grid.map[r * grid.width + c],
              cell = current.nodeAt(p)!,
              span = _span(cell, 'colspan');
          if (span > 1) {
            final attrs = {...cell.attrs, 'colspan': span - 1};
            if (cell.attrs['colwidth'] case final List widths) {
              final next = List<Object?>.of(widths)
                ..removeAt(c - grid.colCount(p));
              attrs['colwidth'] = next.any((v) => v != 0) ? next : null;
            }
            tr.step(_SetNodeStep(mapped(p), cell.withAttrs(attrs)));
          } else {
            tr.replace(mapped(p), mapped(p) + cell.nodeSize);
          }
          r += _span(cell, 'rowspan');
        }
      }
      if (tableContext(tr.doc, tr.selection.head)?.tablePosition != start - 1) {
        final current = tr.doc.nodeAt(start - 1)!;
        tr.setSelection(
          Selection.near(tr.doc, start + current.nodeSize - 2, bias: -1),
        );
      } else {
        tr.setSelection(Selection.near(tr.doc, tr.selection.head));
      }
      return true;
    }
    if (name == 'toggleHeaderRow') {
      final columnHeader = List.generate(
        map.height,
        (r) => table.nodeAt(map.map[r * map.width])!.type == 'tableHeader',
      ).every((v) => v);
      final cells = map.cellsInRect(
        CellRect(columnHeader ? 1 : 0, 0, map.width, 1),
      );
      final all = cells.every((p) => table.nodeAt(p)!.type == 'tableHeader');
      for (final p in cells) {
        final cell = table.nodeAt(p)!;
        markup(
          p,
          schema.node(
            all ? 'tableCell' : 'tableHeader',
            attrs: cell.attrs,
            content: cell.content,
          ),
        );
      }
      return true;
    }
    return false;
  }

  void _tableAddRow(Transaction tr, TableContext context, int row) {
    final table = context.table, map = context.map, start = context.tableStart;
    final ref = row > 0 ? -1 : 0;
    final header = List.generate(
      map.width,
      (c) =>
          table.nodeAt(map.map[(row + ref) * map.width + c])!.type ==
          'tableHeader',
    ).every((v) => v);
    final int? reference = header
        ? (row == 0 || row == map.height ? null : 0)
        : ref;
    final cells = <Node>[];
    for (var col = 0; col < map.width; col++) {
      final index = row * map.width + col;
      if (row > 0 &&
          row < map.height &&
          map.map[index] == map.map[index - map.width]) {
        final p = map.map[index], cell = table.nodeAt(p)!;
        tr.step(AttrStep(start + p, 'rowspan', _span(cell, 'rowspan') + 1));
        col += _span(cell, 'colspan') - 1;
      } else {
        cells.add(
          tr.doc.schema.createAndFill(
            reference == null
                ? 'tableCell'
                : table.nodeAt(map.map[index + reference * map.width])!.type,
          )!,
        );
      }
    }
    final p = start + table.content.positionAt(row);
    tr.replace(
      p,
      p,
      Slice(Fragment([tr.doc.schema.node('tableRow', content: cells)]), 0, 0),
    );
  }
}
