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
    );
    render._header = header;
    render._footer = footer;
    render._codeBlockHeader = codeBlockHeader;
    render._nodeViews = nodeViews;
    render._nodeHeightEstimator = nodeHeightEstimator;
    onReady(render);
    return render;
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderEditorViewport renderObject,
  ) {
    if (renderObject._header != header ||
        renderObject._footer != footer ||
        renderObject._codeBlockHeader != codeBlockHeader) {
      renderObject.markNeedsLayout();
    }
    renderObject._header = header;
    renderObject._footer = footer;
    renderObject._codeBlockHeader = codeBlockHeader;
    renderObject._nodeViews = nodeViews;
    renderObject._nodeHeightEstimator = nodeHeightEstimator;
    renderObject.update(
      controller,
      offset,
      style,
      placeholder,
      bottomMargin,
      codeHighlighter,
      readOnly,
      onTaskToggle,
    );
    onReady(renderObject);
  }
}

class _RenderEditorViewport extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _NodeViewParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _NodeViewParentData>
    implements TiptapGeometry {
  void _buildNodeViews(Set<int> visible) =>
      invokeLayoutCallback<BoxConstraints>(
        (_) => _childManager?._buildVisible(visible),
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
  final Expando<double> _nodeSizes = Expando<double>();
  final Expando<double> _nodeWidths = Expando<double>();
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

  Rect? _childTableClip(_NodeViewParentData data) {
    if (data.row < 0 || _doc.rowCount == 0) return null;
    final index = _indexForPosition(data.position), row = _row(index);
    if (row.table == null) return null;
    // Row-spanning media may extend across several virtual rows.
    return Rect.fromLTWH(
      _rowOrigin(index).dx,
      0,
      _contentWidth - row.indent,
      size.height,
    );
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
  ) : _doc = _controller.state.doc;
  TiptapController _controller;
  ViewportOffset _offset;
  TiptapEditorStyle _style;
  String _placeholder;
  double _bottomMargin;
  final VoidCallback _onGeometry;
  m.Node _doc;
  TiptapCodeHighlighter? _highlighter;
  bool _readOnly;
  ValueChanged<int> _onTaskToggle;
  Expando<TextSpan> _highlights = Expando<TextSpan>();
  Expando<Map<String, ui.Paragraph>> _chrome =
      Expando<Map<String, ui.Paragraph>>();
  final Map<int, _Row> _rows = {};
  final Expando<double> _codeOffsets = Expando<double>();
  ScrollPositionWithSingleContext? _horizontalPosition;
  m.Node? _horizontalBlock;
  int? _horizontalBlockPosition;

  void _unbindHorizontal() {
    final position = _horizontalPosition, block = _horizontalBlock;
    position?.goIdle();
    if (position != null && block != null && position.hasContentDimensions) {
      _codeOffsets[block] = position.pixels.clamp(
        0.0,
        position.maxScrollExtent,
      );
      markNeedsLayout();
      markNeedsPaint();
    }
    _horizontalPosition = null;
    _horizontalBlock = null;
    _horizontalBlockPosition = null;
  }

  void _applyHorizontalDimensions() {
    final position = _horizontalPosition,
        blockPosition = _horizontalBlockPosition;
    if (position == null || blockPosition == null) return;
    final metrics = horizontalScrollMetrics(blockPosition);
    if (metrics == null) {
      _unbindHorizontal();
      return;
    }
    position.applyViewportDimension(metrics.viewport.width);
    while (!position.applyContentDimensions(0, metrics.maxScrollExtent)) {}
    _codeOffsets[_horizontalBlock!] = position.pixels;
  }

  void _setHorizontalOffset(m.Node block, double pixels) {
    if (_codeOffsets[block] == pixels) return;
    _codeOffsets[block] = pixels;
    _showOverflowIndicator(block);
    markNeedsLayout();
    markNeedsPaint();
    _scheduleGeometry();
  }

  final Map<int, SemanticsNode> _taskSemantics = {};
  Ticker? _overflowTicker;
  m.Node? _scrollingBlock;
  double _indicatorOpacity = 0;

  void _showOverflowIndicator(m.Node block) {
    _scrollingBlock = block;
    _indicatorOpacity = 1;
    _overflowTicker ??= Ticker((elapsed) {
      final fade = elapsed - _style.overflowIndicatorHold;
      if (fade.isNegative) return;
      final duration = _style.overflowIndicatorFade.inMicroseconds;
      _indicatorOpacity = duration <= 0
          ? 0
          : (1 - fade.inMicroseconds / duration).clamp(0.0, 1.0);
      markNeedsPaint();
      if (_indicatorOpacity == 0) _overflowTicker!.stop();
    });
    _overflowTicker!.stop();
    _overflowTicker!.start();
  }

  _Row _row(int index) => _rows[index] ??= _Row.at(_doc, index, _style);
  TiptapHeightIndex? _heights;
  // 64 entries cover several 932px text screens; 32K text bounds long blocks.
  static const _layoutLimit = 64, _layoutTextLimit = 32768;
  final _layouts = HashMap<m.Node, _BlockLayout>.identity();
  final _layoutOrder = LinkedList<_BlockLayout>();
  final Set<_BlockLayout> _usedLayouts = {}, _retiredLayouts = {};
  int _cachedTextLength = 0;
  bool _trimScheduled = false;

  void _cacheDiagnostics() {
    _controller.diagnostics.cachedLayouts = _layouts.length;
    _controller.diagnostics.cachedTextLength = _cachedTextLength;
  }

  _BlockLayout _useLayout(m.Node node, _BlockLayout Function() create) {
    var layout = _layouts[node];
    if (layout == null) {
      layout = create();
      _layouts[node] = layout;
      _cachedTextLength += layout.text.length;
      _cacheDiagnostics();
    }
    _touchLayout(layout);
    if (layout is _TableRowLayout) {
      for (final cell in layout.cells) {
        for (final block in cell.blocks) {
          _touchLayout(block.$1);
        }
      }
    }
    if (!_trimScheduled) {
      _trimScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _trimScheduled = false;
        if (attached) _trimLayouts();
      });
    }
    return layout;
  }

  void _touchLayout(_BlockLayout layout) {
    if (_layoutOrder.isEmpty || !identical(_layoutOrder.last, layout)) {
      if (layout.list != null) layout.unlink();
      _layoutOrder.add(layout);
    }
    _usedLayouts.add(layout);
  }

  void _retireLayout(m.Node node) {
    final layout = _layouts.remove(node);
    if (layout == null) return;
    layout.unlink();
    _cachedTextLength -= layout.text.length;
    _retiredLayouts.add(layout);
    _cacheDiagnostics();
  }

  void _trimLayouts() {
    for (final layout in _retiredLayouts) {
      layout.dispose();
    }
    _retiredLayouts.clear();
    if (_layouts.length <= _layoutLimit &&
        _cachedTextLength <= _layoutTextLimit) {
      _usedLayouts.clear();
      return;
    }
    final protected = Set<_BlockLayout>.of(_usedLayouts);
    _usedLayouts.clear();
    void protect(int index) {
      final layout = _layouts[_row(index).node];
      if (layout == null) return;
      protected.add(layout);
      if (layout is _TableRowLayout) {
        for (final cell in layout.cells) {
          protected.addAll(cell.blocks.map((block) => block.$1));
        }
      }
    }

    if (_doc.rowCount > 0) {
      for (
        var index = _firstVisible;
        index < math.min(_lastVisible, _doc.rowCount);
        index++
      ) {
        protect(index);
      }
      protect(_indexForPosition(_controller.state.selection.head));
      protect(_indexForPosition(_controller.state.selection.anchor));
      if (_horizontalBlockPosition case final position?) {
        protect(_indexForPosition(position));
      }
    }
    var removed = true;
    while (removed &&
        (_layouts.length > _layoutLimit ||
            _cachedTextLength > _layoutTextLimit)) {
      removed = false;
      for (final layout in _layoutOrder.toList()) {
        if (_layouts.length <= _layoutLimit &&
            _cachedTextLength <= _layoutTextLimit) {
          break;
        }
        if (protected.contains(layout) || layout.tableUsers.isNotEmpty) {
          continue;
        }
        _layouts.remove(layout.node);
        layout.unlink();
        _cachedTextLength -= layout.text.length;
        layout.dispose();
        removed = true;
      }
    }
    _cacheDiagnostics();
  }

  void _clearLayouts() {
    final layouts = {..._layouts.values, ..._retiredLayouts};
    for (final layout in layouts.whereType<_TableRowLayout>()) {
      layout.dispose();
    }
    for (final layout in layouts) {
      if (layout is! _TableRowLayout) layout.dispose();
    }
    _layoutOrder.clear();
    _layouts.clear();
    _usedLayouts.clear();
    _retiredLayouts.clear();
    _cachedTextLength = 0;
    _cacheDiagnostics();
  }

  double _contentWidth = 1;
  int _firstVisible = 0, _lastVisible = 0;
  bool _geometryScheduled = false;
  bool _inLayout = false;
  bool _cacheReady = false;
  // Keep the unrestricted (possibly negative or beyond max extent) offset of
  // the frame actually painted. Row lookup may clamp an index, never this
  // transform. Geometry, node children and text must share this translation.
  double _layoutOffset = 0, _paintOffset = 0;
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
  ) {
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
      if (attached) _controller.removeListener(_changed);
      _clearLayouts();
      _controller = controller;
      _doc = controller.state.doc;
      _heights = null;
      _rows.clear();
      if (attached) _controller.addListener(_changed);
      markNeedsLayout();
    }
    if (!identical(offset, _offset)) {
      if (attached) _offset.removeListener(_scrolled);
      _offset = offset;
      if (attached) _offset.addListener(_scrolled);
      markNeedsLayout();
    }
    if (style != _style) {
      _clearLayouts();
      _style = style;
      _rows.clear();
      _highlights = Expando<TextSpan>();
      _chrome = Expando<Map<String, ui.Paragraph>>();
      _heights = null;
      _placeholderParagraph = null;
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
    PaintingBinding.instance.systemFonts.addListener(_fontsChanged);
    _offset.addListener(_scrolled);
    _changed();
  }

  @override
  void detach() {
    _unbindHorizontal();
    _overflowTicker?.dispose();
    _overflowTicker = null;
    _indicatorOpacity = 0;
    _controller.removeListener(_changed);
    PaintingBinding.instance.systemFonts.removeListener(_fontsChanged);
    _offset.removeListener(_scrolled);
    _clearLayouts();
    super.detach();
  }

  @override
  void dispose() {
    _clearLayouts();
    _placeholderParagraph?.dispose();
    _placeholderParagraph = null;
    super.dispose();
  }

  void _fontsChanged() {
    _clearLayouts();
    _chrome = Expando<Map<String, ui.Paragraph>>();
    _placeholderParagraph = null;
    markNeedsLayout();
    markNeedsPaint();
  }

  void _scrolled() {
    markNeedsSemanticsUpdate();
    markNeedsLayout();
  }

  void _changed() {
    final next = _controller.state.doc;
    _ensureCaretLayout =
        !identical(next, _doc) ||
        _controller.state.selection is! m.NodeSelection;
    if (!identical(next, _doc)) {
      final transaction = _controller.lastTransaction;
      final mapsDocument =
          transaction != null && identical(transaction.before, _doc);
      if (transaction == null) _cacheReady = false;
      if (transaction != null && identical(transaction.before, _doc)) {
        final documents = transaction.documents;
        for (var i = 1; i < documents.length; i++) {
          _updateRowHeights(documents[i - 1], documents[i]);
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
        if (table?.type == 'table' && _codeOffsets[oldTable] != null) {
          _codeOffsets[table!] = _codeOffsets[oldTable]!;
          if (identical(_horizontalBlock, oldTable)) _horizontalBlock = table;
          if (identical(_scrollingBlock, oldTable)) _scrollingBlock = table;
        }
      }
      if (_horizontalBlockPosition case final position?) {
        final mapped = mapsDocument
            ? transaction.mapping.map(position)
            : position;
        _horizontalBlockPosition = mapped;
        if (mapped < 0 ||
            mapped >= next.content.size ||
            !identical(next.nodeAt(mapped), _horizontalBlock)) {
          _unbindHorizontal();
        }
      }
      _rows.clear();
      _doc = next;
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
      if (range.oldTo - range.from == 1 && range.newTo - range.from == 1) {
        final before = beforeDoc.rowAt(range.from).node,
            after = nextDoc.rowAt(range.from).node;
        if (before.type == 'tableRow' &&
            after.type == 'tableRow' &&
            before.childCount == after.childCount &&
            List.generate(
              before.childCount,
              (c) =>
                  before.child(c).type == after.child(c).type &&
                  mapEquals(before.child(c).attrs, after.child(c).attrs),
            ).every((v) => v)) {
          final oldTable = _Row.at(beforeDoc, range.from, _style).table!,
              newTable = _Row.at(nextDoc, range.from, _style).table!;
          _columnSizes[newTable] = (
            _style.paragraph,
            _style.tableFixedLayout,
            _style.tableMinColumnWidth,
            _tableColumns(oldTable, _style),
          );
        }
      }
      var anchor = heights.indexAt(math.max(0, _offset.pixels - _contentTop));
      final oldY = heights.offsetOf(anchor);
      if (range.oldTo - range.from == range.newTo - range.from) {
        for (var i = range.from; i < range.newTo; i++) {
          final before = beforeDoc.rowAt(i).node, after = nextDoc.rowAt(i).node;
          final cached = _layouts[before];
          if (_codeOffsets[before] case final offset?) {
            _codeOffsets[after] = offset;
            if (identical(_horizontalBlock, before) &&
                before.type == after.type) {
              _horizontalBlock = after;
            }
          }
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
      if (delta.abs() > .01) _offset.correctBy(delta);
    }
  }

  void _scheduleGeometry() {
    if (_geometryScheduled) return;
    _geometryScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _geometryScheduled = false;
      if (attached) _onGeometry();
    });
  }

  bool _inChrome(Offset point) {
    final y = point.dy + _paintOffset - _style.padding.top;
    return y >= 0 && y < _headerHeight ||
        _heights != null &&
            y >= _headerHeight + _heights!.totalHeight &&
            y < _headerHeight + _heights!.totalHeight + _footerHeight;
  }

  _BlockLayout _layoutBlock(int index) {
    final row = _row(index), node = row.node;
    final cached = _layouts[node];
    if (cached is _TableRowLayout && cached.table != row.table) {
      if (cached.rowIndex != row.tableRow ||
          m.TableMap.get(row.table!).hasRowspan ||
          !listEquals(
            _tableColumns(cached.table, _style),
            _tableColumns(row.table!, _style),
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
            )
          : _BlockLayout(node),
    );
    if (layout is _TableRowLayout) {
      layout.blockLayout = (node) => _useLayout(node, () => _BlockLayout(node));
      layout.highlighter = _highlighter;
      layout.nodeHeight = (node, width) => _nodeViews.containsKey(node.type)
          ? _nodeSizes[node] ??
                _nodeHeightEstimator?.call(node, _widthFor(node, width)) ??
                _style.opaqueBlockHeight
          : null;
      final tableFirst = index - row.tableRow;
      layout.rowDistance = (from, to) =>
          _heights!.offsetOf(tableFirst + to) -
          _heights!.offsetOf(tableFirst + from);
    }
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
    if (layout.layout(
      math.max(
        1,
        _contentWidth -
            row.indent -
            row.codeInset * 2 -
            (node.isTextblock || node.type == 'tableRow' ? 0 : 24),
      ),
      _style,
      _controller.diagnostics,
      baseStyle: row.textStyle(_style),
      codeHighlight: highlight,
      firstLineIndent: row.value.path.length == 1 && node.type == 'paragraph'
          ? _style.firstLineIndent
          : 0,
    )) {
      _controller.diagnostics._record(node, index);
    }
    if (_nodeViews.containsKey(node.type)) {
      layout.height =
          _nodeSizes[node] ??
          _nodeHeightEstimator?.call(node, _nodeWidth(index)) ??
          _style.opaqueBlockHeight;
    }
    layout.height = math.max(layout.height, row.minHeight);
    // Geometry and paint may need an offscreen paragraph, but only layout may
    // update row measurements or correct the scroll position.
    if (!_inLayout) return layout;
    final heights = _heights!;
    final anchor = heights.indexAt(math.max(0, _offset.pixels - _contentTop));
    final before = heights.offsetOf(anchor);
    final height =
        layout.height + row.codeTop + row.codeBottom + _spacing(index);
    if ((heights.heightAt(index) - height).abs() > .01) {
      heights.measure(index, height);
      if (!_inLayout) markNeedsLayout();
    }
    if (index < anchor) {
      final delta = heights.offsetOf(anchor) - before;
      if (delta.abs() > .01) _offset.correctBy(delta);
    }
    return layout;
  }

  @override
  void performLayout() {
    _inLayout = true;
    layoutGeneration++;
    size = constraints.constrain(
      Size(
        constraints.hasBoundedWidth ? constraints.maxWidth : 400,
        constraints.hasBoundedHeight ? constraints.maxHeight : 600,
      ),
    );
    final cacheExtent = _cacheReady ? _style.cacheExtent : 0.0;
    _contentWidth = math.max(1, size.width - _style.padding.horizontal);
    _controller.diagnostics.lastLaidOutBlocks.clear();
    if (_heights == null) {
      _controller.diagnostics.fullDocumentScans++;
      _heights = TiptapHeightIndex(
        _doc.rows().map((r) => r.node),
        style: _style,
        width: _contentWidth,
        estimateHeight: (node, width) {
          final percent = node.attrs['widthPercent'];
          return _nodeHeightEstimator?.call(
            node,
            width * (percent is num ? percent.clamp(25, 100) / 100 : 1),
          );
        },
      );
    }
    final heights = _heights!;
    if (heights.width != _contentWidth) {
      final anchor = heights.indexAt(math.max(0, _offset.pixels - _contentTop));
      final oldY = heights.offsetOf(anchor);
      heights.setWidth(_contentWidth);
      _offset.correctBy(heights.offsetOf(anchor) - oldY);
      _placeholderParagraph = null;
    }
    _offset.applyViewportDimension(size.height);
    _buildNodeViews(_visibleNodeRows());
    _measureChrome();
    if (_ensureCaretLayout && _doc.rowCount > 0) {
      _layoutBlock(_indexForPosition(_controller.state.selection.head));
      _ensureCaretLayout = false;
    }
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
      final accepted = _offset.applyContentDimensions(
        0,
        math.max(
          0,
          _style.padding.vertical +
              _headerHeight +
              _footerHeight +
              heights.totalHeight +
              _bottomMargin -
              size.height,
        ),
      );
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
    _applyHorizontalDimensions();
    _positionNodeViews();
    _layoutOffset = _offset.pixels;
    _inLayout = false;
    _rows.removeWhere(
      (index, _) =>
          (index < _firstVisible || index >= _lastVisible) &&
          index != _indexForPosition(_controller.state.selection.head),
    );
    _controller.diagnostics.visibleBlocks = _lastVisible - _firstVisible;
    _controller._searchVisible = (_firstVisible, _lastVisible);
    _scheduleGeometry();
  }

  double _spacing(int index) {
    final row = _row(index);
    if (row.node.type == 'tableRow' &&
        row.tableRow + 1 < row.table!.childCount) {
      return 0;
    }
    if (row.compact &&
        index + 1 < _doc.rowCount &&
        _doc.rowAt(index + 1).position < row.listEnd!) {
      return 0;
    }
    if (_style.blockGap != null) {
      final previous = _doc.child(row.value.path.first);
      if (index + 1 == _doc.rowCount) return _style.blockGap!(previous, null);
      final next = _row(index + 1);
      if (row.value.path.first != next.value.path.first) {
        return _style.blockGap!(previous, _doc.child(next.value.path.first));
      }
    }
    if (index + 1 < _doc.rowCount) {
      final next = _row(index + 1);
      if (next.node.type == 'heading' &&
          next.value.path.length == 1 &&
          _style.headingTopSpacing != null) {
        return _style.headingTopSpacing![(next.node.attrs['level'] as int) - 1];
      }
    }
    if (row.node.type == 'heading' &&
        row.value.path.length == 1 &&
        _style.headingBottomSpacing != null) {
      return _style.headingBottomSpacing!;
    }
    return _style.blockSpacing;
  }

  Offset _rowOrigin(int index) => Offset(
    _style.padding.left + _row(index).indent,
    _contentTop +
        _heights!.offsetOf(index) -
        (_inLayout ? _offset.pixels : _paintOffset),
  );
  double _horizontalExtent(int index) {
    final row = _row(index);
    if (row.table == null &&
        (row.node.type != 'codeBlock' || _style.wrapCodeBlocks)) {
      return 0;
    }
    final available = math.max(
      1.0,
      _contentWidth -
          row.indent -
          row.codePadding.horizontal * (row.table == null ? 1 : 0),
    );
    return math.max(
      0.0,
      _layoutBlock(index).intrinsicWidth -
          available +
          (row.table == null ? _style.caretWidth : 0),
    );
  }

  double _horizontalOffset(int index) {
    final block = _row(index).table ?? _row(index).node;
    final pixels = _codeOffsets[block] ?? 0;
    return identical(block, _horizontalBlock)
        ? pixels
        : pixels.clamp(0.0, _horizontalExtent(index));
  }

  Offset _origin(int index) =>
      _rowOrigin(index) +
      Offset(
        _row(index).codeInset - _horizontalOffset(index),
        _row(index).codeTop,
      );

  int _indexForPosition(int position) =>
      _doc.rowIndexAt(position.clamp(0, _doc.content.size));

  int? _horizontalRowAt(Offset point) {
    if (_heights == null || _doc.rowCount == 0 || _inChrome(point)) return null;
    final index = _heights!.indexAt(point.dy + _paintOffset - _contentTop),
        row = _row(index),
        layout = _layoutBlock(index),
        origin = _rowOrigin(index);
    final rect = Rect.fromLTWH(
      origin.dx,
      origin.dy + row.codeTop,
      _contentWidth - row.indent,
      layout.height,
    );
    return rect.contains(point) && _horizontalExtent(index) > .01
        ? index
        : null;
  }

  bool _scrollCode(Offset point, double delta) {
    final index = _horizontalRowAt(point);
    if (index == null) return false;
    final row = _row(index),
        block = row.table ?? row.node,
        previous = _horizontalOffset(index),
        next = (previous + delta).clamp(0.0, _horizontalExtent(index));
    if (identical(block, _horizontalBlock)) {
      _horizontalPosition!.jumpTo(next);
    } else {
      _setHorizontalOffset(block, next);
    }
    return true;
  }

  @override
  ({
    Rect viewport,
    double offset,
    double maxScrollExtent,
    double indicatorOpacity,
  })?
  horizontalScrollMetrics(int position) {
    if (_heights == null || _doc.rowCount == 0) return null;
    final index = _indexForPosition(position), row = _row(index);
    if (row.table == null && row.node.type != 'codeBlock') return null;
    final origin = _rowOrigin(index), layout = _layoutBlock(index);
    return (
      viewport: Rect.fromLTWH(
        origin.dx + row.codeInset,
        origin.dy + row.codeTop,
        _contentWidth - row.indent - row.codeInset * 2,
        layout.height + row.codeBottom,
      ),
      offset: _horizontalOffset(index),
      maxScrollExtent: _horizontalExtent(index),
      indicatorOpacity: identical(_scrollingBlock, row.table ?? row.node)
          ? _indicatorOpacity
          : 0,
    );
  }

  void _paintOverflow(Canvas canvas, int index) {
    final row = _row(index), metrics = horizontalScrollMetrics(row.position);
    if (metrics == null || metrics.maxScrollExtent <= .01) return;
    final rect = metrics.viewport;
    final background =
        row.table == null ||
            row.tableRow == 0 && row.node.content.first.type == 'tableHeader'
        ? _style.codeBackground
        : _style.overflowBackground;
    final width = math.min(_style.overflowFadeWidth, rect.width / 2);
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
        _style.overflowIndicatorHeight <= 0 ||
        row.table != null && row.tableRow != row.table!.childCount - 1) {
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
          rect.bottom - _style.overflowIndicatorHeight,
          thumb,
          _style.overflowIndicatorHeight,
        ),
        const Radius.circular(2),
      ),
      Paint()
        ..color = _style.overflowIndicatorColor.withValues(
          alpha: _style.overflowIndicatorColor.a * metrics.indicatorOpacity,
        ),
    );
  }

  void _revealHorizontal(int position) {
    if (_heights == null || _doc.rowCount == 0) return;
    final index = _indexForPosition(position), row = _row(index);
    if (row.node.type != 'codeBlock' && row.table == null) return;
    final rect = caretRect(position),
        left = _rowOrigin(index).dx + 12,
        right = _rowOrigin(index).dx + _contentWidth - row.indent - 12;
    final delta = rect.right > right
        ? rect.right - right
        : rect.left < left
        ? rect.left - left
        : 0.0;
    if (delta != 0) {
      _scrollCode(_rowOrigin(index) + Offset(12, row.codeTop + 1), delta);
    }
  }

  List<Rect> _cellSelectionRects() {
    final selection = _controller.state.selection;
    if (selection is! m.CellSelection) return [];
    return [
      for (var i = _firstVisible; i < _lastVisible; i++)
        if (_layoutBlock(i) case final _TableRowLayout table)
          for (final cell in table.cells)
            if (selection.cells.contains(_row(i).position + cell.position))
              cell.rect.shift(_origin(i)),
    ];
  }

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
    final i = _indexForPosition(position),
        row = _row(i),
        layout = _layoutBlock(i);
    if (layout is _TableRowLayout) {
      for (final cell in layout.cells) {
        for (final block in cell.blocks) {
          if (row.position + block.$2 != position) continue;
          final node = block.$1.node, available = cell.rect.width - 20;
          final width = _nodeWidths[node] ?? _widthFor(node, available);
          return _origin(i) +
                  layout._blockOrigin(cell, block.$3) +
                  Offset(
                    _style.centerMedia &&
                            const {'image', 'video'}.contains(node.type)
                        ? (available - width) / 2
                        : 0,
                    0,
                  ) &
              Size(width, block.$1.height);
        }
      }
    }
    return (_nodeViews.containsKey(row.node.type)
            ? _nodeOrigin(i)
            : _rowOrigin(i)) &
        Size(
          _nodeViews.containsKey(row.node.type)
              ? (_nodeWidths[row.node] ?? _nodeWidth(i))
              : math.max(1, _contentWidth - row.indent),
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
          _heights!.offsetOf(index + cell.rowspan) - _heights!.offsetOf(index);
      return _origin(index) + cell.rect.topLeft & Size(cell.rect.width, h);
    }
    return null;
  }

  @override
  Rect? taskCheckboxRect(int position) {
    if (_doc.rowCount == 0 || _heights == null) return null;
    final i = _indexForPosition(position), row = _row(i);
    if (row.taskPosition == null) return null;
    final font = _style.paragraph.fontSize ?? 17;
    return Rect.fromLTWH(
      _rowOrigin(i).dx - (_style.taskIndent ?? _style.listIndent),
      _rowOrigin(i).dy + font * .275,
      font * 1.2,
      font * 1.2,
    );
  }

  int? _taskAt(Offset point) {
    if (_heights == null || _doc.rowCount == 0) return null;
    final i = _heights!.indexAt(point.dy + _paintOffset - _contentTop);
    final row = _row(i), rect = taskCheckboxRect(row.position);
    return rect?.inflate(3).contains(point) == true ? row.taskPosition : null;
  }

  @override
  Size get viewportSize => size;
  @override
  double get scrollOffset => _paintOffset;
  @override
  int positionForOffset(Offset offset) {
    if (_doc.rowCount == 0 || _heights == null) return 0;
    final i = _heights!.indexAt(offset.dy + _paintOffset - _contentTop);
    final layout = _layoutBlock(i), start = _row(i).position;
    if (!layout.node.isTextblock && layout is! _TableRowLayout) return start;
    return start + 1 + layout.position(offset - _origin(i));
  }

  m.Node? _referenceAt(Offset point) {
    if (_heights == null || _doc.rowCount == 0) return null;
    final index = _heights!.indexAt(point.dy + _paintOffset - _contentTop);
    final layout = _layoutBlock(index), origin = _origin(index);
    if (layout is _TableRowLayout) return null;
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

  _CaretGeometry? _lastCaretGeometry;
  Rect _visualCaretRect(int position) {
    if (_controller.state.selection is m.GapSelection ||
        _doc.rowCount == 0 ||
        _heights == null) {
      _lastCaretGeometry = null;
      return caretRect(position);
    }
    final i = _indexForPosition(position), row = _row(i);
    final layout = _layoutBlock(i), origin = _origin(i);
    if (!layout.node.isTextblock && layout is! _TableRowLayout) {
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
    if (!layout.node.isTextblock && layout is! _TableRowLayout) {
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
    if (visibleOnly) {
      a = _firstVisible;
      b = _lastVisible - 1;
    }
    final result = <Rect>[];
    for (var i = a; i <= b; i++) {
      if ((i < originalA || i > originalB) && _row(i).table == null) continue;
      final layout = _layoutBlock(i),
          origin = _origin(i),
          start = _row(i).position;
      if (!layout.node.isTextblock && layout is! _TableRowLayout) {
        result.add(rowRect(start));
        continue;
      }
      result.addAll(
        layout
            .boxes(
              layout is _TableRowLayout
                  ? from - start - 1
                  : (from - start - 1).clamp(0, layout.node.content.size),
              layout is _TableRowLayout
                  ? to - start - 1
                  : (to - start - 1).clamp(0, layout.node.content.size),
            )
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

  TextRange _boundary(int position, bool word) {
    if (_doc.rowCount == 0) return const TextRange.collapsed(0);
    final i = _indexForPosition(position), start = _row(i).position;
    final layout = _layoutBlock(i);
    if (!layout.node.isTextblock && layout is! _TableRowLayout) {
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

  @override
  TextRange wordBoundary(int position) => _boundary(position, true);
  @override
  TextRange lineBoundary(int position) => _boundary(position, false);
  @override
  bool hitTestSelf(Offset position) => true;
  int _paintCount = 0;
  @override
  void paint(PaintingContext context, Offset offset) {
    _paintCount++;
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
      final row = _row(i);
      _layoutBlock(i);
      if (row.node.type == 'codeBlock') {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rowRect(row.position),
            const Radius.circular(12),
          ),
          Paint()..color = _style.codeBackground,
        );
        if (_style.codeHeaderDivider case final divider?
            when _codeBlockHeader != null) {
          final rect = rowRect(row.position),
              y = rect.top + _style.codeBlockPadding.top - 6;
          canvas.drawLine(
            Offset(rect.left, y),
            Offset(rect.right, y),
            Paint()
              ..color = divider
              ..strokeWidth = .5,
          );
        }
      }
      for (final (x, quotePosition) in row.quotes) {
        final continues =
            i + 1 < _doc.rowCount &&
            _row(i + 1).quotes.any((q) => q.$2 == quotePosition);
        canvas.drawRect(
          Rect.fromLTWH(
            _style.padding.left + x,
            _rowOrigin(i).dy,
            _style.quoteBorderWidth,
            _heights!.heightAt(i) - (continues ? 0 : _spacing(i)),
          ),
          Paint()..color = _style.quoteBorderColor,
        );
      }
    }
    // Visible rows are indexed before the background count reaches them.
    if (_controller._searchIndex.query.isNotEmpty) {
      for (var i = _firstVisible; i < _lastVisible; i++) {
        for (final match in _controller._searchIndex.rowMatches(
          _row(i).value,
        )) {
          for (final rect in selectionRects(match.from, match.to)) {
            canvas.drawRect(rect, Paint()..color = const Color(0x66ffcc00));
          }
        }
      }
    }
    if (!selection.empty &&
        selection is! m.NodeSelection &&
        selection is! m.CellSelection) {
      final paint = Paint()..color = _style.selectionColor;
      for (final rect in selectionRects(selection.from, selection.to)) {
        canvas.drawRect(rect, paint);
      }
    }
    for (var i = _firstVisible; i < _lastVisible; i++) {
      final layout = _layoutBlock(i), origin = _origin(i);
      _paintRowChrome(canvas, i);
      if (layout is _TableRowLayout) {
        canvas.save();
        canvas.clipRect(
          _rowOrigin(i) &
              Size(math.max(1, _contentWidth - _row(i).indent), layout.height),
        );
        layout.paint(
          canvas,
          origin,
          _style,
          selection,
          _row(i).position,
          _controller._searchIndex,
        );
        canvas.restore();
      } else if (layout.node.type == 'horizontalRule') {
        _paintRule(canvas, i);
      } else if (_nodeViews.containsKey(layout.node.type)) {
      } else if (!layout.node.isTextblock && layout is! _TableRowLayout) {
        final card = RRect.fromRectAndRadius(
          origin &
              Size(math.max(1, _contentWidth - _row(i).indent), layout.height),
          const Radius.circular(8),
        );
        final selected =
            !_readOnly &&
            selection is m.NodeSelection &&
            selection.from == _row(i).position;
        canvas.drawRRect(card, Paint()..color = _style.opaqueBackground);
        canvas.drawRRect(
          card,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = selected ? 2 : 1
            ..color = selected ? _style.caretColor : _style.opaqueBorder,
        );
        canvas.drawParagraph(
          layout.chunks.first.paragraph!,
          origin +
              Offset(
                12,
                math.max(0, (layout.height - layout.chunks.first.height) / 2),
              ),
        );
      } else {
        if (layout.node.type == 'codeBlock') {
          final card = rowRect(_row(i).position);
          canvas.save();
          canvas.clipRect(
            Rect.fromLTRB(
              card.left + 12,
              card.top + _row(i).codeTop,
              card.right - 12,
              card.bottom - 12,
            ),
          );
        }
        var y = origin.dy;
        for (final chunk in layout.chunks) {
          if (y + chunk.height >= 0 && y <= size.height) {
            _paintInlineChunk(canvas, chunk, Offset(origin.dx, y), _style);
          }
          y += chunk.height;
        }
        if (layout.node.type == 'codeBlock') canvas.restore();
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
      _paintOverflow(canvas, i);
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

  @override
  void assembleSemanticsNode(
    SemanticsNode node,
    SemanticsConfiguration config,
    Iterable<SemanticsNode> children,
  ) {
    final tasks = <SemanticsNode>[];
    final active = <int>{};
    for (var i = _firstVisible; i < _lastVisible; i++) {
      final row = _row(i), position = row.taskPosition;
      if (position == null) continue;
      final rect = taskCheckboxRect(row.position)!;
      if (!rect.overlaps(Offset.zero & size)) continue;
      active.add(position);
      final child = _taskSemantics.putIfAbsent(position, () => SemanticsNode());
      child.rect = taskCheckboxRect(row.position)!
          .intersect(Offset.zero & size);
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
