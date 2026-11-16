part of '../editor.dart';

extension _DocumentSync on _RenderEditorViewport {
  void _documentChanged() {
    final next = _controller.state.doc;
    final transaction = _controller.lastTransaction;
    final move = transaction?.blockMove;
    if (move != null &&
        identical(transaction!.before, _doc) &&
        _heights != null &&
        hasSize) {
      _moveAnchorTop = rowRect(move.before).top;
      _moveAnchorPosition = move.after;
      _moveAnchorOffset = _offset.pixels;
    } else {
      _moveAnchorPosition = null;
    }
    _ensureCaretLayout =
        !identical(next, _doc) ||
        _controller.state.selection is! m.NodeSelection;
    if (!identical(next, _doc)) {
      _visibleLayouts.clear();
      final contentTop = _contentTop;
      final mapsDocument =
          transaction != null && identical(transaction.before, _doc);
      if (mapsDocument) {
        for (final row in _rows.values) {
          final layout = _layouts[row.node];
          if (layout is! _TableRowLayout) continue;
          for (final (block, _) in layout.contentRows(includeTables: true)) {
            final before = block.row.scrollOwner,
                pixels = _horizontal._codeOffsets[block.row.scrollOwner];
            if (!const {'codeBlock', 'table'}.contains(before.type) ||
                pixels == null) {
              continue;
            }
            final position = transaction.mapping.map(
              row.position +
                  block.position -
                  (block.row.table == null
                      ? 0
                      : block.row.tableRowPosition + 1),
            );
            if (position < 0 || position >= next.content.size) continue;
            final after = next.nodeAt(position);
            if (after?.type != before.type) continue;
            _horizontal.carry(before, after!);
          }
        }
      }
      if (transaction == null) {
        _cacheReady = false;
        _nodeSizes.clear();
      }
      if (move != null && mapsDocument) {
        final documents = transaction.documents;
        for (var index = 1; index < documents.length; index++) {
          _updateRowHeights(documents[index - 1], documents[index]);
        }
      } else {
        _updateRowHeights(_doc, next);
      }
      final seen = <m.Node>{};
      for (final row in _rows.values) {
        final oldTable = row.table;
        if (oldTable == null || !seen.add(oldTable)) continue;
        final position = row.position - row.tableRowPosition - 1;
        final mapped =
            transaction != null && identical(transaction.before, _doc)
            ? transaction.mapping.map(position)
            : position;
        final table = next.nodeAt(mapped.clamp(0, next.content.size));
        if (table?.type == 'table' &&
            _horizontal._codeOffsets[oldTable] != null) {
          _horizontal.carry(oldTable, table!);
        }
      }
      if (_horizontal._horizontalBlockPosition case final position?) {
        final mapped = mapsDocument
            ? transaction.mapping.map(position)
            : position;
        _horizontal._horizontalBlockPosition = mapped;
        if (mapped < 0 ||
            mapped >= next.content.size ||
            !identical(next.nodeAt(mapped), _horizontal._horizontalBlock)) {
          _horizontal.unbind();
        }
      }
      _rows.clear();
      _doc = next;
      if (_offset.pixels > 0) {
        _correctScroll(_contentTop - contentTop);
      }
      markNeedsLayout();
      markNeedsSemanticsUpdate();
    }
    markNeedsLayout();
    markNeedsPaint();
    _scheduleGeometry();
  }

  void _updateRowHeights(m.Node beforeDoc, m.Node nextDoc) {
    final heights = _heights;
    if (heights != null) {
      final range = beforeDoc.changedRows(nextDoc);
      var anchor = heights.indexAt(math.max(0, _offset.pixels - _contentTop));
      final oldY = heights.offsetOf(anchor);
      if (range.oldTo - range.from == range.newTo - range.from) {
        for (var i = range.from; i < range.newTo; i++) {
          final before = beforeDoc.rowAt(i).node, after = nextDoc.rowAt(i).node;
          _nodeSizes.carry(before, after);
          final cached = _layouts[before];
          _horizontal.carry(before, after, scrolling: false, requireType: true);
          if (cached != null &&
              cached.tableUsers.isEmpty &&
              after.type != 'tableRow' &&
              !identical(before, after)) {
            final revised = _layouts.containsKey(after)
                ? null
                : cached.revise(after);
            _retireLayout(before);
            if (revised != null) _useLayout(after, () => revised);
          } else if (cached?.tableUsers.isEmpty == true &&
              !identical(before, after)) {
            _retireLayout(before);
          }
        }
      }
      heights.replace(
        range.from,
        range.oldTo,
        nextDoc.rows(from: range.from, to: range.newTo).map((r) => r.node),
      );
      if (anchor >= range.oldTo) {
        anchor += range.newTo - range.oldTo;
      } else if (anchor >= range.from) {
        anchor = math.min(anchor, math.max(range.from, range.newTo - 1));
      }
      anchor = anchor.clamp(0, heights.length);
      final delta = heights.offsetOf(anchor) - oldY;
      if (delta.abs() > .01) {
        _correctScroll(delta);
      }
    }
  }

  void _measureRow(int index, double height) {
    final heights = _heights!;
    final delta = height - heights.heightAt(index);
    if (delta.abs() <= .01) return;
    final top = _offset.pixels - _contentTop;
    final anchor = heights.indexAt(math.max(0, top));
    final correct =
        heights.offsetOf(index) < top - .01 &&
        (index < anchor || !_resizing && (_readOnly || index != _headIndex));
    heights.measure(index, height);
    if (correct) _correctScroll(delta);
  }

  void _reestimateNodeHeights() {
    if (_invalidatedNodeHeights.isEmpty) return;
    final nodes = Set<m.Node>.of(_invalidatedNodeHeights);
    _invalidatedNodeHeights.clear();
    _nodeSizes.invalidate(nodes);
    final tables = <_TableRowLayout>{};
    for (final node in nodes) {
      final layout = _layouts[node];
      if (layout != null) _invalidateTableUsers(layout, tables);
    }
    var index = 0;
    for (final row in _doc.rows()) {
      var affected = nodes.contains(row.node);
      if (!affected && row.node.type == 'tableRow') {
        row.node.descendants((node, position, parent, childIndex) {
          if (nodes.contains(node)) affected = true;
          return !affected && !node.isTextblock;
        });
      }
      if (affected) {
        final layout = _layouts[row.node];
        if (layout is _TableRowLayout) layout.invalidate();
        _layoutBlock(index);
      }
      index++;
    }
  }

  void _restoreMoveAnchor() {
    final position = _moveAnchorPosition;
    if (position == null) return;
    final top = rowRect(position).top + _offset.pixels;
    final target = (top - _moveAnchorTop).clamp(0.0, _maxScrollExtent);
    final delta = target - _offset.pixels;
    if (delta.abs() > .01) _offset.correctBy(delta);
    _moveAnchorOffset = _offset.pixels;
  }
}
