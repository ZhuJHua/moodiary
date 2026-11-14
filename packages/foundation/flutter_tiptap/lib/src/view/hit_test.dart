part of '../editor.dart';

extension _ViewportHitTest on _RenderEditorViewport {
  int? _taskAt(Offset point) {
    if (_heights == null || _doc.rowCount == 0) return null;
    final index = _rowIndexAt(point);
    for (final block in _contentBlocks(index)) {
      if (block.clip != null && !block.clip!.contains(point)) continue;
      final rect = _checkboxFor(block.row, block.origin);
      if (rect?.inflate(3).contains(point) == true) return block.taskPosition;
    }
    return null;
  }

  m.Node? _referenceAt(Offset point) {
    if (_heights == null || _doc.rowCount == 0) return null;
    for (final block in _contentBlocks(_rowIndexAt(point))) {
      if (block.clip != null && !block.clip!.contains(point)) continue;
      final found = _referenceIn(block.layout, block.textOrigin, point);
      if (found != null) return found;
    }
    return null;
  }

  m.Node? _referenceIn(_BlockLayout layout, Offset origin, Offset point) {
    var y = origin.dy;
    for (final chunk in layout.chunks) {
      final boxes = chunk.paragraph!.getBoxesForPlaceholders();
      for (var c = 0; c < chunk.chips.length; c++) {
        if (boxes[chunk.chips[c].$3]
            .toRect()
            .shift(Offset(origin.dx, y))
            .contains(point)) {
          return chunk.chips[c].$1;
        }
      }
      y += chunk.height;
    }
    return null;
  }

  bool _inChrome(Offset point) {
    final y = point.dy + _paintOffset - _style.padding.top;
    return y >= 0 && y < _headerHeight ||
        _heights != null &&
            y >= _headerHeight + _heights!.totalHeight &&
            y < _headerHeight + _heights!.totalHeight + _footerHeight;
  }

  Rect _caretForInput(int position) {
    if (_heights == null || _doc.rowCount == 0) return caretRect(position);
    final i = _indexForPosition(position);
    if (i >= _firstVisible && i < _lastVisible) return caretRect(position);
    final cached = _layouts[_row(i).node];
    if (cached?.width == _contentWidth && identical(cached?.style, _style)) {
      return caretRect(position);
    }
    final text = _style.forBlock(_row(i).node);
    return _origin(i) &
        Size(_style.caretWidth, (text.fontSize ?? 17) * (text.height ?? 1.5));
  }

  Rect _visualCaretRect(int position) {
    if (_controller.state.selection is m.GapSelection ||
        _doc.rowCount == 0 ||
        _heights == null) {
      _lastCaretGeometry = null;
      return caretRect(position);
    }
    final i = _indexForPosition(position), row = _row(i);
    final layout = _layoutBlock(i), origin = _origin(i);
    if (_row(i).value.isAtomRow) {
      _lastCaretGeometry = null;
      return caretRect(position);
    }
    final value = layout
        .caretGeometry(
          (position - row.position - 1).clamp(0, layout.node.content.size),
          _style.caretWidth,
          _style.caretHeightFactor,
        )
        .shift(origin);
    _lastCaretGeometry = value;
    return value.rect;
  }

  TextRange _boundary(int position, bool word) {
    if (_doc.rowCount == 0) return const TextRange.collapsed(0);
    final i = _indexForPosition(position), start = _row(i).position;
    final layout = _layoutBlock(i);
    if (!layout.hasText && layout is! _TableRowLayout) {
      return TextRange(start: start, end: start + layout.node.nodeSize);
    }
    final range = layout.boundary(
      (position - start - 1).clamp(0, layout.node.content.size),
      word: word,
    );
    return TextRange(
      start: start + 1 + math.max(0, range.start),
      end: start + 1 + math.max(0, range.end),
    );
  }

  Rect? _childTableClip(_NodeViewParentData data) {
    if (data.row < 0 || _doc.rowCount == 0) return null;
    final index = _indexForPosition(data.position), row = _row(index);
    if (row.table == null) return null;
    final cell = cellRect(data.position);
    if (cell == null) return null;
    Rect? clip;
    for (final block in _contentBlocks(index)) {
      if (block.containsPosition(data.position)) {
        clip = block.clip;
        break;
      }
    }
    final visible = clip == null
        ? cell
        : cell.intersect(Rect.fromLTWH(clip.left, 0, clip.width, size.height));
    return visible.intersect(
      Rect.fromLTWH(
        _rowOrigin(index).dx,
        0,
        _contentWidth - row.indent,
        size.height,
      ),
    );
  }
}
