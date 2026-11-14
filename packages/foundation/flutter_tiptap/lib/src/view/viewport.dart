part of '../editor.dart';

class _EditorViewport extends RenderObjectWidget {
  const _EditorViewport({
    required this.controller,
    required this.offset,
    required this.style,
    required this.placeholder,
    required this.bottomMargin,
    required this.onReady,
    required this.codeHighlighter,
    required this.readOnly,
    required this.onTaskToggle,
    required this.onGeometry,
    required this.onCaretLayout,
    required this.nodeViews,
    this.nodeHeightEstimator,
    this.header,
    this.footer,
    this.codeBlockHeader,
  });
  final Widget? header, footer;
  final TiptapNodeViewBuilder? codeBlockHeader;
  final Map<String, TiptapNodeViewBuilder> nodeViews;
  final TiptapNodeHeightEstimator? nodeHeightEstimator;
  @override
  RenderObjectElement createElement() => _ViewportElement(this);
  final TiptapController controller;
  final ViewportOffset offset;
  final TiptapEditorStyle style;
  final bool readOnly;
  final TiptapCodeHighlighter? codeHighlighter;
  final ValueChanged<int> onTaskToggle;
  final String placeholder;
  final double bottomMargin;
  final ValueChanged<_RenderEditorViewport> onReady;
  final VoidCallback onGeometry;
  final ValueChanged<_RenderEditorViewport> onCaretLayout;
  @override
  _RenderEditorViewport createRenderObject(BuildContext context) {
    final render = _RenderEditorViewport(
      controller,
      offset,
      style,
      placeholder,
      bottomMargin,
      onGeometry,
      codeHighlighter,
      readOnly,
      onTaskToggle,
      onCaretLayout,
      header,
      footer,
      codeBlockHeader,
      nodeViews,
      nodeHeightEstimator,
    );
    onReady(render);
    return render;
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderEditorViewport renderObject,
  ) {
    renderObject.update(
      controller,
      offset,
      style,
      placeholder,
      bottomMargin,
      codeHighlighter,
      readOnly,
      onTaskToggle,
      header,
      footer,
      codeBlockHeader,
      nodeViews,
      nodeHeightEstimator,
    );
    onReady(renderObject);
  }
}

class _RenderEditorViewport extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _NodeViewParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _NodeViewParentData>
    implements TiptapGeometry, _LayoutHost {
  void _buildNodeViews(Map<int, _ViewTarget> entries) =>
      invokeLayoutCallback<BoxConstraints>(
        (_) => _childManager?._buildVisible(entries),
      );
  Widget? _header, _footer;
  TiptapNodeViewBuilder? _codeBlockHeader;
  double _headerHeight = 0, _footerHeight = 0;
  double get _contentTop =>
      _style.padding.top +
      _headerHeight +
      (_doc.childCount == 0
          ? 0
          : _style.blockGap?.call(null, _doc.child(0)) ?? 0);
  _ViewportElement? _childManager;
  Map<String, TiptapNodeViewBuilder> _nodeViews = const {};
  TiptapNodeHeightEstimator? _nodeHeightEstimator;
  late final _nodeSizes = _MeasuredSizes(() => _controller.diagnostics);
  final _invalidatedNodeHeights = <m.Node>{};

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _NodeViewParentData) {
      child.parentData = _NodeViewParentData();
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    var child = lastChild;
    while (child != null) {
      final data = child.parentData! as _NodeViewParentData;
      final clip = _childTableClip(data);
      if ((clip == null || clip.contains(position)) &&
          result.addWithPaintOffset(
            offset: data.offset,
            position: position,
            hitTest: (result, point) => child!.hitTest(result, position: point),
          )) {
        return true;
      }
      child = data.previousSibling;
    }
    return false;
  }

  _RenderEditorViewport(
    this._controller,
    this._offset,
    this._style,
    this._placeholder,
    this._bottomMargin,
    this._onGeometry,
    this._highlighter,
    this._readOnly,
    this._onTaskToggle,
    this._onCaretLayout,
    this._header,
    this._footer,
    this._codeBlockHeader,
    this._nodeViews,
    this._nodeHeightEstimator,
  ) : _doc = _controller.state.doc;
  TiptapController _controller;
  ViewportOffset _offset;
  TiptapEditorStyle _style;
  String _placeholder;
  double _bottomMargin;
  final VoidCallback _onGeometry;
  final ValueChanged<_RenderEditorViewport> _onCaretLayout;
  m.Node _doc;
  TiptapCodeHighlighter? _highlighter;
  bool _readOnly;
  ValueChanged<int> _onTaskToggle;
  Expando<TextSpan> _highlights = Expando<TextSpan>();
  Expando<_LruMap<String, ui.Paragraph>> _chrome =
      Expando<_LruMap<String, ui.Paragraph>>();
  final Map<int, _Row> _rows = {};
  final Map<int, _BlockLayout> _visibleLayouts = {};
  int _headIndex = 0;
  late final _horizontal = _HorizontalScroll(this);

  final Map<int, SemanticsNode> _taskSemantics = {};

  _Row _row(int index) => _rows[index] ??= _Row.at(_doc, index, _style);
  TiptapHeightIndex? _heights;
  int? _moveAnchorPosition;
  double _moveAnchorTop = 0, _moveAnchorOffset = 0;
  // 64 entries cover several 932px text screens; 32K text bounds long blocks.
  static const _layoutLimit = 64, _layoutTextLimit = 32768;
  final _layouts = HashMap<m.Node, _BlockLayout>.identity();
  var _tableGeometries = Expando<_TableGeometry>();
  final _layoutOrder = LinkedList<_BlockLayout>();
  final Set<_BlockLayout> _usedLayouts = {}, _retiredLayouts = {};
  int _cachedTextLength = 0;
  bool _trimScheduled = false;

  double _contentWidth = 1;
  int _firstVisible = 0, _lastVisible = 0;
  bool _geometryScheduled = false;
  bool _inLayout = false;
  bool _resizing = false;
  bool _cacheReady = false;
  // Keep the unrestricted (possibly negative or beyond max extent) offset of
  // the frame actually painted. Row lookup may clamp an index, never this
  // transform. Geometry, node children and text must share this translation.
  double _layoutOffset = 0, _paintOffset = 0;
  @override
  int layoutGeneration = 0;
  bool _ensureCaretLayout = true;
  ui.Paragraph? _placeholderParagraph;
  void update(
    TiptapController controller,
    ViewportOffset offset,
    TiptapEditorStyle style,
    String placeholder,
    double bottomMargin,
    TiptapCodeHighlighter? highlighter,
    bool readOnly,
    ValueChanged<int> onTaskToggle,
    Widget? header,
    Widget? footer,
    TiptapNodeViewBuilder? codeBlockHeader,
    Map<String, TiptapNodeViewBuilder> nodeViews,
    TiptapNodeHeightEstimator? nodeHeightEstimator,
  ) {
    if (_header != header ||
        _footer != footer ||
        _codeBlockHeader != codeBlockHeader) {
      markNeedsLayout();
    }
    _header = header;
    _footer = footer;
    _codeBlockHeader = codeBlockHeader;
    _nodeViews = nodeViews;
    _nodeHeightEstimator = nodeHeightEstimator;
    if (!identical(_highlighter, highlighter)) {
      _highlighter = highlighter;
      _highlights = Expando<TextSpan>();
      markNeedsLayout();
    }
    if (_readOnly != readOnly) markNeedsSemanticsUpdate();
    _readOnly = readOnly;
    _onTaskToggle = onTaskToggle;
    if (_bottomMargin != bottomMargin) {
      _bottomMargin = bottomMargin;
      markNeedsLayout();
    }
    if (!identical(controller, _controller)) {
      if (attached) {
        _controller.removeListener(_changed);
        _controller._searchRepaint.removeListener(markNeedsPaint);
        _controller._nodeHeights.removeListener(_nodeHeightsChanged);
      }
      _invalidateLayout(heights: true);
      _controller = controller;
      _moveAnchorPosition = null;
      _doc = controller.state.doc;
      if (attached) {
        _controller.addListener(_changed);
        _controller._searchRepaint.addListener(markNeedsPaint);
        _controller._nodeHeights.addListener(_nodeHeightsChanged);
      }
      markNeedsLayout();
    }
    if (!identical(offset, _offset)) {
      if (attached) _offset.removeListener(_scrolled);
      _offset = offset;
      _moveAnchorPosition = null;
      if (attached) _offset.addListener(_scrolled);
      markNeedsLayout();
    }
    if (style != _style) {
      _invalidateLayout(heights: true, styles: true);
      _style = style;
      markNeedsLayout();
    }
    if (placeholder != _placeholder) {
      _placeholder = placeholder;
      _placeholderParagraph = null;
    }
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller.addListener(_changed);
    _controller._searchRepaint.addListener(markNeedsPaint);
    _controller._nodeHeights.addListener(_nodeHeightsChanged);
    PaintingBinding.instance.systemFonts.addListener(_fontsChanged);
    _offset.addListener(_scrolled);
    _changed();
  }

  @override
  void detach() {
    _horizontal.dispose();
    _controller.removeListener(_changed);
    _controller._searchRepaint.removeListener(markNeedsPaint);
    _controller._nodeHeights.removeListener(_nodeHeightsChanged);
    PaintingBinding.instance.systemFonts.removeListener(_fontsChanged);
    _offset.removeListener(_scrolled);
    _clearLayouts();
    super.detach();
  }

  @override
  void dispose() {
    _invalidateLayout();
    _placeholderParagraph?.dispose();
    _placeholderParagraph = null;
    super.dispose();
  }

  bool get _scrollAnchored => _moveAnchorPosition != null;

  void _correctScroll(double delta) {
    if (!_scrollAnchored) _offset.correctBy(delta);
  }

  void _fontsChanged() {
    _invalidateLayout(fonts: true);
    markNeedsLayout();
    markNeedsPaint();
  }

  void _scrolled() {
    if (!_inLayout && (_offset.pixels - _moveAnchorOffset).abs() > .01) {
      _moveAnchorPosition = null;
    }
    markNeedsSemanticsUpdate();
    markNeedsLayout();
  }

  void _changed() => _documentChanged();
  void _nodeHeightsChanged() {
    _invalidatedNodeHeights.addAll(_controller._invalidatedNodeHeights);
    markNeedsLayout();
  }

  void _scheduleGeometry() {
    if (_geometryScheduled) return;
    _geometryScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _geometryScheduled = false;
      if (attached) _onGeometry();
    });
  }

  @override
  _BlockLayout blockLayout(_Row row) => _layoutForRow(row);

  @override
  void layoutRow(
    _Row row,
    _BlockLayout layout,
    double available, {
    bool header = false,
    TextAlign? textAlign,
  }) => _layoutContentRow(
    row,
    layout,
    available,
    header: header,
    textAlign: textAlign,
  );

  @override
  void releaseMeasurement(_BlockLayout layout) => _usedLayouts.remove(layout);

  @override
  double codeOffset(_CellRow row) => _horizontal.codeOffset(row);
  @override
  int get codeOffsetGeneration => _horizontal.generation;

  _BlockLayout _layoutForRow(_Row row) {
    final node = row.node;
    final cached = _layouts[node];
    if (cached is _TableRowLayout && cached.table != row.table) {
      if (cached.rowIndex != row.tableRow ||
          cached.geometry.spans ||
          m.TableMap.get(row.table!).hasRowspan ||
          !listEquals(
            _tableColumns(cached.table, _style, cached.width ?? _contentWidth),
            _tableColumns(row.table!, _style, cached.width ?? _contentWidth),
          )) {
        _retireLayout(node);
      } else {
        cached.table = row.table!;
        cached.rowPosition = row.tableRowPosition;
      }
    }
    final layout = _useLayout(
      node,
      () => node.type == 'tableRow'
          ? _TableRowLayout(
              node,
              row.table!,
              row.tableRow,
              row.tableRowPosition,
              this,
            )
          : _BlockLayout(node),
    );
    if (layout is _TableRowLayout) {
      if (m.TableMap.get(row.table!).hasRowspan) {
        layout.geometry = _tableGeometries[row.table!] ??= _TableGeometry();
      }
    }
    return layout;
  }

  _BlockLayout _layoutBlock(int index) {
    if (!_inLayout) {
      final cached = _visibleLayouts[index];
      if (cached != null &&
          identical(cached.node, _row(index).node) &&
          cached.width != null) {
        return cached;
      }
    }
    final row = _row(index), node = row.node, layout = _layoutForRow(row);
    if (_layoutContentRow(row, layout, _contentWidth)) {
      _controller.diagnostics._record(node, index);
    }
    // Geometry and paint may need an offscreen paragraph, but only layout may
    // update row measurements or correct the scroll position.
    if (!_inLayout) return layout;
    _visibleLayouts[index] = layout;
    if (layout is _TableRowLayout && layout.geometry.spans) {
      final offsets = layout.geometry.offsets, first = index - row.tableRow;
      for (var tableRow = 0; tableRow + 1 < offsets.length; tableRow++) {
        _measureRow(
          first + tableRow,
          offsets[tableRow + 1] -
              offsets[tableRow] +
              _spacing(first + tableRow),
        );
      }
      return layout;
    }
    final height =
        layout.height + row.codeTop + row.codeBottom + _spacing(index);
    _measureRow(index, height);
    return layout;
  }

  double get _maxScrollExtent => math.max(
    0,
    _style.padding.vertical +
        _headerHeight +
        _footerHeight +
        _heights!.totalHeight +
        _bottomMargin -
        size.height,
  );

  @override
  void performLayout() {
    _inLayout = true;
    _visibleLayouts.clear();
    _headIndex = _indexForPosition(_controller.state.selection.head);
    layoutGeneration++;
    size = constraints.constrain(
      Size(
        constraints.hasBoundedWidth ? constraints.maxWidth : 400,
        constraints.hasBoundedHeight ? constraints.maxHeight : 600,
      ),
    );
    final cacheExtent = _cacheReady ? _style.cacheExtent : 0.0;
    _contentWidth = math.max(1, size.width - _style.padding.horizontal);
    if (_heights == null) {
      _controller.diagnostics.fullDocumentScans++;
      _heights = TiptapHeightIndex(
        _doc.rows().map((r) => r.node),
        style: _style,
        width: _contentWidth,
        estimateHeight: (node, width) {
          final available = _widthFor(
            node,
            width,
            clampWidth: false,
            usePreview: false,
          );
          return _nodeSizes.get(node, available)?.height ??
              _nodeHeightEstimator?.call(node, available);
        },
      );
    }
    final heights = _heights!;
    _resizing = heights.width != _contentWidth;
    if (_resizing) {
      final anchor = heights.indexAt(math.max(0, _offset.pixels - _contentTop));
      final oldY = heights.offsetOf(anchor);
      heights.setWidth(_contentWidth);
      _correctScroll(heights.offsetOf(anchor) - oldY);
      _placeholderParagraph = null;
    }
    _offset.applyViewportDimension(size.height);
    _reestimateNodeHeights();
    _restoreMoveAnchor();
    _buildNodeViews(_visibleViews(_visibleNodeRows()));
    _measureChrome();
    if (_ensureCaretLayout && _doc.rowCount > 0) {
      _layoutBlock(_indexForPosition(_controller.state.selection.head));
      _ensureCaretLayout = false;
    }
    _restoreMoveAnchor();
    for (var pass = 0; pass < 12; pass++) {
      if (heights.length == 0) break;
      final first = heights.indexAt(
        math.max(0, _offset.pixels - _contentTop - cacheExtent),
      );
      var last = first;

      for (var i = first; i < heights.length; i++) {
        if (_contentTop + heights.offsetOf(i) >
            _offset.pixels + size.height + cacheExtent) {
          break;
        }
        _layoutBlock(i);
        last = i + 1;
      }
      _firstVisible = first;
      _lastVisible = last;
      final nodeViewsStable = _layoutNodeViews();
      _restoreMoveAnchor();
      final accepted = _offset.applyContentDimensions(0, _maxScrollExtent);
      final currentFirst = heights.indexAt(
        math.max(0, _offset.pixels - _contentTop - cacheExtent),
      );
      final currentLast =
          heights.indexAt(
            math.max(
              0,
              _offset.pixels + size.height + cacheExtent - _contentTop,
            ),
          ) +
          1;
      if (accepted &&
          currentFirst == first &&
          currentLast <= last &&
          nodeViewsStable) {
        break;
      }
    }
    _horizontal._applyHorizontalDimensions();
    _positionNodeViews();
    _layoutOffset = _offset.pixels;
    _inLayout = false;
    _paintOffset = _layoutOffset;
    _onCaretLayout(this);
    _resizing = false;
    final headIndex = _indexForPosition(_controller.state.selection.head);
    _rows.removeWhere(
      (index, _) =>
          (index < _firstVisible || index >= _lastVisible) &&
          index != headIndex,
    );
    _controller.diagnostics.visibleBlocks = _lastVisible - _firstVisible;
    _controller._searchVisible = (_firstVisible, _lastVisible);
    _scheduleGeometry();
  }

  double _spacing(int index) => _row(index).spacing(
    _doc,
    index,
    _style,
    next: index + 1 < _doc.rowCount ? _row(index + 1) : null,
  );

  bool _layoutContentRow(
    _Row row,
    _BlockLayout layout,
    double available, {
    bool header = false,
    TextAlign? textAlign,
  }) {
    row.fit(available, _style);
    final node = row.node;
    TextSpan? highlight;
    if (node.type == 'codeBlock' && _highlighter != null) {
      highlight = _highlights[node];
      if (highlight == null) {
        final spans = _highlighter!(
          node.attrs['language'] as String?,
          layout.text,
        );
        highlight = spans.toPlainText() == layout.text
            ? spans
            : TextSpan(text: layout.text);
        _highlights[node] = highlight;
      }
    }
    final changed = layout.layout(
      math.max(
        1,
        available -
            row.indent -
            row.codePadding.horizontal * (node.type == 'codeBlock' ? 1 : 0) -
            (row.value.isAtomRow ? 24 : 0),
      ),
      _style,
      _controller.diagnostics,
      baseStyle: header
          ? row.textStyle(_style).copyWith(fontWeight: FontWeight.w600)
          : row.textStyle(_style),
      textAlign: textAlign,
      codeHighlight: highlight,
      firstLineIndent: row.value.path.length == 1 && node.type == 'paragraph'
          ? _style.firstLineIndent
          : 0,
    );
    if (_nodeViews.containsKey(node.type)) {
      final width = _widthFor(node, math.max(1, available - row.indent));
      layout.height =
          _nodeSizes.get(node, width)?.height ??
          _nodeHeightEstimator?.call(node, width) ??
          _style.opaqueBlockHeight;
    }
    layout.height = math.max(layout.height, row.minHeight);
    return changed;
  }

  Offset _rowOrigin(int index) => Offset(
    _style.padding.left + _row(index).indent,
    _contentTop +
        _heights!.offsetOf(index) -
        (_inLayout ? _offset.pixels : _paintOffset),
  );

  Offset _origin(int index) =>
      _rowOrigin(index) +
      Offset(
        _row(index).codeInset - _horizontal._horizontalOffset(index),
        _row(index).codeTop,
      );

  int _indexForPosition(int position) =>
      _doc.rowIndexAt(position.clamp(0, _doc.content.size));

  @override
  _HorizontalMetrics? horizontalScrollMetrics(int position) =>
      _horizontal.metrics(position);

  List<Rect> _searchRects() => [
    for (var i = _firstVisible; i < _lastVisible; i++)
      for (final match in _controller._searchIndex.rowMatches(
        _row(i).value,
        preparedOnly: true,
      ))
        ...selectionRects(
          match.from,
          match.to,
        ).where((r) => r.overlaps(Offset.zero & size)),
  ];
  @override
  int get rowCount => _doc.rowCount;
  @override
  Rect rowRect(int position) {
    final index = _indexForPosition(position);
    for (final block in _contentBlocks(index)) {
      if (block.cellRow != null && !block.containsPosition(position)) continue;
      if (block.cellRow != null ||
          _nodeViews.containsKey(block.row.node.type)) {
        final (origin, width) = _mediaBox(
          block.layout.node,
          block.origin,
          block.width,
          measured: true,
          clampCenter: block.cellRow == null,
        );
        return origin & Size(width, block.height);
      }
      return block.origin & Size(math.max(1, block.width), block.height);
    }
    final row = _row(index), layout = _layoutBlock(index);
    return _rowOrigin(index) &
        Size(
          math.max(1, _contentWidth - row.indent),
          layout.height + row.codeTop + row.codeBottom,
        );
  }

  @override
  Rect? cellRect(int position) {
    final context = m.tableContext(_doc, position);
    if (context == null || _heights == null) return null;
    final index = _indexForPosition(context.cellPosition + 1),
        layout = _layoutBlock(index);
    if (layout is! _TableRowLayout) return null;
    for (final cell in layout.cells) {
      if (_row(index).position + cell.position != context.cellPosition) {
        continue;
      }
      final h =
          _heights!.offsetOf(index + cell.rowspan) -
          _heights!.offsetOf(index) -
          _spacing(index + cell.rowspan - 1);
      return _origin(index) + cell.rect.topLeft & Size(cell.rect.width, h);
    }
    return layout
        .nestedCellRect(context.cellPosition - _row(index).position)
        ?.shift(_origin(index));
  }

  @override
  Rect? taskCheckboxRect(int position) {
    if (_doc.rowCount == 0 || _heights == null) return null;
    for (final block in _contentBlocks(_indexForPosition(position))) {
      if (block.cellRow == null || block.containsPosition(position)) {
        return _checkboxFor(block.row, block.origin);
      }
    }
    return null;
  }

  @override
  Size get viewportSize => size;
  @override
  double get scrollOffset => _paintOffset;
  @override
  int positionForOffset(Offset offset) {
    if (_doc.rowCount == 0 || _heights == null) return 0;
    final i = _rowIndexAt(offset);
    final layout = _layoutBlock(i), start = _row(i).position;
    if (_row(i).value.isAtomRow) return start;
    return start + 1 + layout.position(offset - _origin(i));
  }

  _CaretGeometry? _lastCaretGeometry;

  @override
  Rect caretRect(int position) {
    if (_doc.rowCount == 0 || _heights == null) {
      return Rect.fromLTWH(
        _style.padding.left,
        _contentTop,
        _style.caretWidth,
        24,
      );
    }
    final i = _indexForPosition(position), start = _row(i).position;
    final layout = _layoutBlock(i), origin = _origin(i);
    if (_controller.state.selection is m.GapSelection) {
      final pos = _doc.resolve(position);
      final after = pos.nodeAfter, before = pos.nodeBefore;
      final nodePosition = after != null
          ? position
          : position - (before?.nodeSize ?? 0);
      final rect = rowRect(nodePosition);
      return Rect.fromLTWH(
        rect.left,
        after != null ? rect.top + 1 : rect.bottom - 2,
        20,
        2,
      );
    }
    if (!layout.hasText && layout is! _TableRowLayout) {
      return Rect.fromLTWH(
        origin.dx,
        origin.dy,
        _style.caretWidth,
        layout.height,
      );
    }
    return layout
        .caret(
          (position - start - 1).clamp(0, layout.node.content.size),
          _style.caretWidth,
        )
        .shift(origin);
  }

  @override
  List<Rect> selectionRects(int from, int to, {bool visibleOnly = true}) {
    if (_doc.rowCount == 0 || from >= to || _heights == null) return [];
    var a = _indexForPosition(from), b = _indexForPosition(to - 1);
    final originalA = a, originalB = b;
    final first = _row(a), last = _row(b);
    if (first.table != null && m.TableMap.get(first.table!).hasRowspan) {
      a -= first.tableRow;
    }
    if (last.table case final table? when m.TableMap.get(table).hasRowspan) {
      b += table.childCount - last.tableRow - 1;
    }
    if (visibleOnly) {
      a = math.max(a, _firstVisible);
      b = math.min(b, _lastVisible - 1);
    }
    final result = <Rect>[];
    for (var i = a; i <= b; i++) {
      if ((i < originalA || i > originalB) && _row(i).table == null) continue;
      final layout = _layoutBlock(i),
          origin = _origin(i),
          start = _row(i).position;
      if (!layout.hasText && layout is! _TableRowLayout) {
        result.add(rowRect(start));
        continue;
      }
      result.addAll(
        layout
            .boxes(from - start - 1, to - start - 1)
            .map((rect) => rect.shift(origin))
            .map(
              (rect) => layout is _TableRowLayout
                  ? rect.intersect(
                      _rowOrigin(i) &
                          Size(_contentWidth - _row(i).indent, layout.height),
                    )
                  : layout.node.type == 'codeBlock'
                  ? rect.intersect(rowRect(start).deflate(12))
                  : rect,
            )
            .where((rect) => !rect.isEmpty),
      );
    }
    return result;
  }

  @override
  TextRange wordBoundary(int position) => _boundary(position, true);
  @override
  TextRange lineBoundary(int position) => _boundary(position, false);
  @override
  bool hitTestSelf(Offset position) => true;
  void _paintCellRows(
    Canvas canvas,
    int index,
    _TableRowLayout layout, {
    required bool background,
  }) {
    canvas.save();
    canvas.clipRect(
      _rowOrigin(index) &
          Size(math.max(1, _contentWidth - _row(index).indent), layout.height),
    );
    layout.paint(
      canvas,
      _origin(index),
      _style,
      background: background,
      paintRow: (block, card, text, next) {
        final rect = card & Size(block.width, block.height);
        if (background) {
          _paintBlockBackground(
            canvas,
            block.row,
            rect,
            continues: (position) =>
                next?.quotes.any((quote) => quote.$2 == position) ?? false,
            spacing: block.spacing,
          );
        } else if (block.layout is! _TableRowLayout) {
          _paintBlockContent(
            canvas,
            block.row,
            block.layout,
            text,
            rect,
            _row(index).position + block.position,
          );
        }
      },
    );
    canvas.restore();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_cacheReady) {
      _cacheReady = true;
      // Shape the offscreen cache only after the document's first paint.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (attached) markNeedsLayout();
      });
    }
    _paintOffset = _layoutOffset;
    var canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.clipRect(Offset.zero & size);
    final selection = _controller.state.selection;
    for (var i = _firstVisible; i < _lastVisible; i++) {
      final row = _row(i), layout = _layoutBlock(i);
      _paintBlockBackground(
        canvas,
        row,
        rowRect(row.position),
        continues: (position) =>
            i + 1 < _doc.rowCount &&
            _row(i + 1).quotes.any((quote) => quote.$2 == position),
        spacing: _spacing(i),
        quoteLeft: _style.padding.left,
      );
      if (layout is _TableRowLayout) {
        _paintCellRows(canvas, i, layout, background: true);
      }
    }
    // Visible rows are indexed before the background count reaches them.
    if (_controller._searchIndex.query.isNotEmpty) {
      final paint = Paint()..color = const Color(0x66ffcc00);
      for (var i = _firstVisible; i < _lastVisible; i++) {
        for (final match in _controller._searchIndex.rowMatches(
          _row(i).value,
          preparedOnly: true,
        )) {
          for (final rect in selectionRects(match.from, match.to)) {
            canvas.drawRect(rect, paint);
          }
        }
      }
    }
    if (!selection.empty && selection is! m.NodeSelection) {
      final paint = Paint()..color = _style.selectionColor;
      for (final rect in selectionRects(selection.from, selection.to)) {
        canvas.drawRect(rect, paint);
      }
    }
    for (var i = _firstVisible; i < _lastVisible; i++) {
      final row = _row(i), layout = _layoutBlock(i);
      if (layout is _TableRowLayout) {
        _paintCellRows(canvas, i, layout, background: false);
      } else {
        _paintBlockContent(
          canvas,
          row,
          layout,
          _origin(i),
          rowRect(row.position),
          row.position,
        );
      }
    }
    if (_placeholder.isNotEmpty &&
        _doc.childCount == 1 &&
        _doc.blocks.first.isTextblock &&
        _doc.blocks.first.content.isEmpty) {
      _placeholderParagraph ??=
          (ui.ParagraphBuilder(
                  ui.ParagraphStyle(textDirection: _style.textDirection),
                )
                ..pushStyle(_style.placeholderStyle.getTextStyle())
                ..addText(_placeholder))
              .build()
            ..layout(ui.ParagraphConstraints(width: _contentWidth));
      canvas.drawParagraph(_placeholderParagraph!, _origin(0));
    }
    canvas.restore();
    context.pushClipRect(needsCompositing, offset, Offset.zero & size, (
      context,
      offset,
    ) {
      var child = firstChild;
      while (child != null) {
        final current = child,
            data = current.parentData! as _NodeViewParentData;
        final clip = _childTableClip(data);
        if (clip == null) {
          context.paintChild(current, offset + data.offset);
        } else {
          context.pushClipRect(needsCompositing, offset, clip, (
            context,
            offset,
          ) {
            context.paintChild(current, offset + data.offset);
          });
        }
        child = data.nextSibling;
      }
    });
    canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.clipRect(Offset.zero & size);
    for (var i = _firstVisible; i < _lastVisible; i++) {
      _horizontal._paintOverflow(canvas, i);
    }
    if (!_readOnly &&
        selection is m.NodeSelection &&
        _nodeViews.containsKey(_doc.nodeAt(selection.from)?.type)) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rowRect(selection.from).deflate(1),
          const Radius.circular(12),
        ),
        Paint()
          ..color = _style.caretColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    final composing = _controller.composing;
    if (composing.isValid && !composing.isCollapsed) {
      final paint = Paint()
        ..color = _style.composingColor
        ..strokeWidth = 1.5;
      for (final rect in selectionRects(composing.start, composing.end)) {
        canvas.drawLine(rect.bottomLeft, rect.bottomRight, paint);
      }
    }

    canvas.restore();
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isSemanticBoundary = true;
    config.isTextField = true;
    config.isReadOnly = _readOnly;
    config.textDirection = _style.textDirection;
  }

  Iterable<(int, _Row, Rect)> _visibleTasks() sync* {
    final viewport = Offset.zero & size;
    for (var index = _firstVisible; index < _lastVisible; index++) {
      for (final block in _contentBlocks(index)) {
        final rect = _checkboxFor(block.row, block.origin);
        if (rect == null) continue;
        final clip = (block.clip == null ? rect : rect.intersect(block.clip!))
            .intersect(viewport);
        if (block.clip == null ? rect.overlaps(viewport) : !clip.isEmpty) {
          yield (block.taskPosition!, block.row, clip);
        }
      }
    }
  }

  @override
  void assembleSemanticsNode(
    SemanticsNode node,
    SemanticsConfiguration config,
    Iterable<SemanticsNode> children,
  ) {
    final tasks = <SemanticsNode>[];
    final active = <int>{};
    for (final (position, row, rect) in _visibleTasks()) {
      if (!active.add(position)) {
        final child = _taskSemantics[position]!;
        child.rect = child.rect.expandToInclude(rect);
        continue;
      }
      final child = _taskSemantics.putIfAbsent(position, () => SemanticsNode());
      child.rect = rect;
      final semantics = SemanticsConfiguration()
        ..isSemanticBoundary = true
        ..textDirection = _style.textDirection
        ..label = row.node.textContent
        ..isChecked = row.taskChecked
        ..isEnabled = !_readOnly;
      if (!_readOnly) semantics.onTap = () => _onTaskToggle(position);
      child.updateWith(config: semantics);
      tasks.add(child);
    }
    _taskSemantics.removeWhere((position, _) => !active.contains(position));
    node.updateWith(
      config: config,
      childrenInInversePaintOrder: [...children, ...tasks.reversed],
    );
  }
}
