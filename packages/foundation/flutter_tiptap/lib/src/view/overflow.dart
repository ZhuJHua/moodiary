part of '../editor.dart';

typedef _HorizontalMetrics = ({
  Rect viewport,
  double offset,
  double maxScrollExtent,
  double indicatorOpacity,
});

class _HorizontalScroll {
  _HorizontalScroll(this.host);
  final _RenderEditorViewport host;
  final _codeOffsets = Expando<double>();
  int generation = 0;
  void _writeOffset(m.Node node, double pixels) {
    if (_codeOffsets[node] == pixels) return;
    _codeOffsets[node] = pixels;
    generation++;
  }

  ScrollPositionWithSingleContext? _horizontalPosition;
  m.Node? _horizontalBlock;
  int? _horizontalBlockPosition;
  Ticker? _overflowTicker;
  m.Node? _scrollingBlock;
  double _indicatorOpacity = 0;

  bool get bound => _horizontalBlock != null;

  void updatePixels(double pixels) {
    final block = _horizontalBlock;
    if (block != null) _setHorizontalOffset(block, pixels);
  }

  void bind(
    m.Node block,
    int blockPosition,
    ScrollPositionWithSingleContext position,
    double pixels,
  ) {
    if (!identical(_horizontalBlock, block)) {
      unbind();
      position.goIdle();
      position.correctPixels(pixels);
      _horizontalBlock = block;
      generation++;
      _horizontalBlockPosition = blockPosition;
      _horizontalPosition = position;
    }
    _applyHorizontalDimensions();
  }

  void scrollTo(m.Node block, double pixels) {
    if (identical(block, _horizontalBlock)) {
      _horizontalPosition!.jumpTo(pixels);
    } else {
      _setHorizontalOffset(block, pixels);
    }
  }

  void carry(
    m.Node before,
    m.Node after, {
    bool scrolling = true,
    bool requireType = false,
  }) {
    final pixels = _codeOffsets[before];
    if (pixels == null) return;
    _writeOffset(after, pixels);
    if (identical(_horizontalBlock, before) &&
        (!requireType || before.type == after.type)) {
      _horizontalBlock = after;
    }
    if (scrolling && identical(_scrollingBlock, before)) {
      _scrollingBlock = after;
    }
  }

  void dispose() {
    unbind();
    _overflowTicker?.dispose();
    _overflowTicker = null;
    _indicatorOpacity = 0;
  }

  void unbind() {
    final position = _horizontalPosition, block = _horizontalBlock;
    position?.goIdle();
    if (position != null && block != null && position.hasContentDimensions) {
      _writeOffset(block, position.pixels.clamp(0.0, position.maxScrollExtent));
      host.markNeedsLayout();
      host.markNeedsPaint();
    }
    _horizontalPosition = null;
    _horizontalBlock = null;
    generation++;
    _horizontalBlockPosition = null;
  }

  void _applyHorizontalDimensions() {
    final position = _horizontalPosition,
        blockPosition = _horizontalBlockPosition;
    if (position == null || blockPosition == null) return;
    final metrics = this.metrics(blockPosition);
    if (metrics == null) {
      unbind();
      return;
    }
    position.applyViewportDimension(metrics.viewport.width);
    while (!position.applyContentDimensions(0, metrics.maxScrollExtent)) {}
    _writeOffset(_horizontalBlock!, position.pixels);
  }

  void _setHorizontalOffset(m.Node block, double pixels) {
    if (_codeOffsets[block] == pixels) return;
    _writeOffset(block, pixels);
    _showOverflowIndicator(block);
    host.markNeedsLayout();
    host.markNeedsPaint();
    host._scheduleGeometry();
  }

  void _showOverflowIndicator(m.Node block) {
    _scrollingBlock = block;
    _indicatorOpacity = 1;
    _overflowTicker ??= Ticker((elapsed) {
      final fade = elapsed - host._style.overflowIndicatorHold;
      if (fade.isNegative) return;
      final duration = host._style.overflowIndicatorFade.inMicroseconds;
      _indicatorOpacity = duration <= 0
          ? 0
          : (1 - fade.inMicroseconds / duration).clamp(0.0, 1.0);
      host.markNeedsPaint();
      if (_indicatorOpacity == 0) _overflowTicker!.stop();
    });
    _overflowTicker!.stop();
    _overflowTicker!.start();
  }

  double _horizontalExtent(int index) {
    final row = host._row(index);
    if (row.table == null &&
        (row.node.type != 'codeBlock' || host._style.wrapCodeBlocks)) {
      return 0;
    }
    final available = math.max(
      1.0,
      host._contentWidth -
          row.indent -
          row.codePadding.horizontal * (row.table == null ? 1 : 0),
    );
    return math.max(
      0.0,
      host._layoutBlock(index).intrinsicWidth -
          available +
          (row.table == null ? host._style.caretWidth : 0),
    );
  }

  double _horizontalOffset(int index) {
    final block = host._row(index).scrollOwner;
    final pixels = _codeOffsets[block] ?? 0;
    return identical(block, _horizontalBlock)
        ? pixels
        : pixels.clamp(0.0, _horizontalExtent(index));
  }

  double _cellOverflowExtent(_CellRow row) {
    if (row.layout is _TableRowLayout) {
      return math.max(0, row.layout.intrinsicWidth - row.width);
    }
    return row.row.node.type != 'codeBlock' || host._style.wrapCodeBlocks
        ? 0
        : math.max(
            0,
            row.layout.intrinsicWidth -
                math.max(1, row.width - row.row.codePadding.horizontal) +
                host._style.caretWidth,
          );
  }

  _ContentBlock? _cellOverflowAt(Offset point, int index) {
    _ContentBlock? found;
    for (final block in host._contentBlocks(index, includeTables: true)) {
      final cell = block.cellRow;
      if (cell != null &&
          block.clip!.contains(point) &&
          block.rect.contains(point) &&
          _cellOverflowExtent(cell) > .01) {
        found = block;
      }
    }
    return found;
  }

  (m.Node, int, double) _horizontalTarget(Offset point, int index) {
    final row = host._row(index), block = _cellOverflowAt(point, index);
    if (block != null) {
      return (
        block.row.scrollOwner,
        block.scrollOwnerPosition,
        codeOffset(block.cellRow!),
      );
    }
    return (row.scrollOwner, row.scrollOwnerPosition, _horizontalOffset(index));
  }

  int? _horizontalRowAt(Offset point) {
    if (host._heights == null ||
        host._doc.rowCount == 0 ||
        host._inChrome(point)) {
      return null;
    }
    final index = host._rowIndexAt(point),
        row = host._row(index),
        layout = host._layoutBlock(index),
        origin = host._rowOrigin(index);
    if (_cellOverflowAt(point, index) != null) return index;
    final rect = Rect.fromLTWH(
      origin.dx,
      origin.dy + row.codeTop,
      host._contentWidth - row.indent,
      layout.height,
    );
    return rect.contains(point) && _horizontalExtent(index) > .01
        ? index
        : null;
  }

  bool _scrollCode(Offset point, double delta) {
    final index = _horizontalRowAt(point);
    if (index == null) return false;
    final (block, position, previous) = _horizontalTarget(point, index);
    final metrics = this.metrics(position)!;
    final next = (previous + delta).clamp(0.0, metrics.maxScrollExtent);
    scrollTo(block, next);
    return true;
  }

  _HorizontalMetrics _cellScrollMetrics(_ContentBlock block) {
    final point = block.origin;
    return (
      viewport: Rect.fromLTWH(
        point.dx + block.row.codeInset,
        point.dy + block.row.codeTop,
        math.max(
          1,
          block.width -
              (block.row.isCode ? block.row.codePadding.horizontal : 0),
        ),
        block.layout.height + block.row.codeBottom,
      ),
      offset: codeOffset(block.cellRow!),
      maxScrollExtent: _cellOverflowExtent(block.cellRow!),
      indicatorOpacity: identical(_scrollingBlock, block.row.scrollOwner)
          ? _indicatorOpacity
          : 0,
    );
  }

  void _paintOverflow(Canvas canvas, int index) {
    final row = host._row(index), metrics = this.metrics(row.position);
    if (row.table != null) {
      final layout = host._layoutBlock(index);
      canvas.save();
      canvas.clipRect(
        host._rowOrigin(index) &
            Size(host._contentWidth - row.indent, layout.height),
      );
      for (final block in host._contentBlocks(index, includeTables: true)) {
        if (!block.row.isCode && block.layout is! _TableRowLayout) continue;
        canvas.save();
        canvas.clipRect(block.clip!);
        _paintOverflowMetrics(
          canvas,
          _cellScrollMetrics(block),
          block.row.overflowBackground(host._style),
          indicator: block.row.showsOverflowIndicator,
        );
        canvas.restore();
      }
      canvas.restore();
    }
    if (metrics == null || metrics.maxScrollExtent <= .01) return;
    _paintOverflowMetrics(
      canvas,
      metrics,
      row.overflowBackground(host._style),
      indicator: row.showsOverflowIndicator,
    );
  }

  void _paintOverflowMetrics(
    Canvas canvas,
    ({
      Rect viewport,
      double offset,
      double maxScrollExtent,
      double indicatorOpacity,
    })
    metrics,
    Color background, {
    bool indicator = true,
  }) {
    if (metrics.maxScrollExtent <= .01) return;
    final rect = metrics.viewport;
    final width = math.min(host._style.overflowFadeWidth, rect.width / 2);
    void fade(bool left) {
      if (width <= 0) return;
      final edge = Rect.fromLTWH(
        left ? rect.left : rect.right - width,
        rect.top,
        width,
        rect.height,
      );
      canvas.drawRect(
        edge,
        Paint()
          ..shader = ui.Gradient.linear(
            edge.topLeft,
            edge.topRight,
            left
                ? [background, background.withValues(alpha: 0)]
                : [background.withValues(alpha: 0), background],
          ),
      );
    }

    if (metrics.offset > .01) fade(true);
    if (metrics.offset < metrics.maxScrollExtent - .01) fade(false);
    if (metrics.indicatorOpacity <= 0 ||
        host._style.overflowIndicatorHeight <= 0 ||
        !indicator) {
      return;
    }
    final contentWidth = rect.width + metrics.maxScrollExtent,
        thumb = math
            .max(24.0, rect.width * rect.width / contentWidth)
            .clamp(0.0, rect.width),
        x =
            rect.left +
            (rect.width - thumb) * metrics.offset / metrics.maxScrollExtent;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x,
          rect.bottom - host._style.overflowIndicatorHeight,
          thumb,
          host._style.overflowIndicatorHeight,
        ),
        const Radius.circular(2),
      ),
      Paint()
        ..color = host._style.overflowIndicatorColor.withValues(
          alpha:
              host._style.overflowIndicatorColor.a * metrics.indicatorOpacity,
        ),
    );
  }

  void _revealHorizontal(int position) {
    final index = host._indexForPosition(position), row = host._row(index);
    if (!row.isCode && row.table == null) return;
    if (row.table != null) {
      final blocks = host._contentBlocks(index, includeTables: true).toList();
      for (final block in blocks) {
        if (!block.row.isCode || !block.containsPosition(position)) continue;
        final metrics = this.metrics(position)!;
        final caret = host.caretRect(position);
        final delta = _revealDelta(
          caret,
          metrics.viewport.left,
          metrics.viewport.right,
        );
        if (delta != 0) {
          scrollTo(
            block.row.node,
            (metrics.offset + delta).clamp(0.0, metrics.maxScrollExtent),
          );
        }
        break;
      }
      for (final block in blocks.reversed) {
        if (block.layout is! _TableRowLayout ||
            !block.containsPosition(position)) {
          continue;
        }
        final caret = host.caretRect(position), point = block.origin;
        final delta = _revealDelta(
          caret,
          point.dx + 12,
          point.dx + block.width - 12,
        );
        if (delta == 0) continue;
        final cell = block.cellRow!;
        final pixels = (codeOffset(cell) + delta).clamp(
          0.0,
          _cellOverflowExtent(cell),
        );
        scrollTo(block.row.table!, pixels);
      }
    }
    final rect = host.caretRect(position), origin = host._rowOrigin(index);
    final delta = _revealDelta(
      rect,
      origin.dx + 12,
      origin.dx + host._contentWidth - row.indent - 12,
    );
    if (delta != 0) _scrollCode(origin + Offset(12, row.codeTop + 1), delta);
  }

  _HorizontalMetrics? metrics(int position) {
    if (host._heights == null || host._doc.rowCount == 0) return null;
    final index = host._indexForPosition(position), row = host._row(index);
    if (row.table == null && row.node.type != 'codeBlock') return null;
    final origin = host._rowOrigin(index), layout = host._layoutBlock(index);
    if (row.table != null && position > row.position) {
      for (final block in host._contentBlocks(index, includeTables: true)) {
        final matches = block.row.isCode
            ? block.containsPosition(position)
            : block.row.table != null && position == block.scrollOwnerPosition;
        if (matches) return _cellScrollMetrics(block);
      }
    }
    return (
      viewport: Rect.fromLTWH(
        origin.dx + row.codeInset,
        origin.dy + row.codeTop,
        host._contentWidth - row.indent - row.codeInset * 2,
        layout.height + row.codeBottom,
      ),
      offset: _horizontalOffset(index),
      maxScrollExtent: _horizontalExtent(index),
      indicatorOpacity: identical(_scrollingBlock, row.scrollOwner)
          ? _indicatorOpacity
          : 0,
    );
  }

  double codeOffset(_CellRow row) {
    final extent = _cellOverflowExtent(row);
    final node = row.scrollOwner;
    final pixels = _codeOffsets[node] ?? 0;
    return identical(node, _horizontalBlock)
        ? pixels
        : pixels.clamp(0.0, extent);
  }
}

double _revealDelta(Rect caret, double left, double right) =>
    caret.right > right
    ? caret.right - right
    : caret.left < left
    ? caret.left - left
    : 0;

class _OverflowScrollContext implements ScrollContext {
  _OverflowScrollContext(this.state);
  final TiptapEditorState state;

  @override
  BuildContext get notificationContext => state.context;
  @override
  BuildContext get storageContext => state.context;
  @override
  TickerProvider get vsync => state;
  @override
  AxisDirection get axisDirection => AxisDirection.right;
  @override
  double get devicePixelRatio => MediaQuery.devicePixelRatioOf(state.context);
  @override
  void setIgnorePointer(bool value) {}
  @override
  void setCanDrag(bool value) {}
  @override
  void setSemanticsActions(Set<ui.SemanticsAction> actions) {}
  @override
  void saveOffset(double offset) {}
}

class _OverflowDragRecognizer extends HorizontalDragGestureRecognizer {
  bool Function(Offset point)? canStart;
  @override
  bool isPointerAllowed(PointerEvent event) =>
      (canStart?.call(event.position) ?? false) &&
      super.isPointerAllowed(event);
}
