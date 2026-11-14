part of '../editor.dart';

class _NodeViewParentData extends ContainerBoxParentData<RenderBox> {
  int row = 0;
  int position = 0;
}

/// Children are requested from layout, as in SliverMultiBoxAdaptorElement.
class _ViewportElement extends RenderObjectElement {
  _ViewportElement(_EditorViewport super.widget);
  final Map<int, Element> _children = {};
  final Map<int, Element> _chromeChildren = {};
  final Map<int, m.Node> _viewNodes = {};
  final Map<
    int,
    ({TiptapNodeView view, TiptapNodeViewBuilder builder, Widget child})
  >
  _viewWidgets = {};
  @override
  _EditorViewport get widget => super.widget as _EditorViewport;
  @override
  _RenderEditorViewport get renderObject =>
      super.renderObject as _RenderEditorViewport;
  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    renderObject._childManager = this;
  }

  @override
  void update(covariant _EditorViewport newWidget) {
    final old = widget;
    super.update(newWidget);
    if (old.style != newWidget.style || old.readOnly != newWidget.readOnly) {
      _viewWidgets.clear();
    }
    if (!mapEquals(old.nodeViews, newWidget.nodeViews) ||
        old.nodeHeightEstimator != newWidget.nodeHeightEstimator) {
      renderObject.markNeedsLayout();
    }
  }

  void _buildVisible(Map<int, _ViewTarget> entries) {
    owner!.buildScope(this, () {
      for (final slot in [-1, -2]) {
        final child = updateChild(
          _chromeChildren[slot],
          slot == -1 ? widget.header : widget.footer,
          slot,
        );
        if (child == null) {
          _chromeChildren.remove(slot);
        } else {
          _chromeChildren[slot] = child;
        }
      }
      final remaining = Map<int, Element>.of(_children),
          nextChildren = <int, Element>{},
          nextNodes = <int, m.Node>{},
          nextWidgets =
              <
                int,
                ({
                  TiptapNodeView view,
                  TiptapNodeViewBuilder builder,
                  Widget child,
                })
              >{};
      final previousSlots = HashMap<m.Node, Queue<int>>.identity();
      for (final entry in _viewNodes.entries) {
        (previousSlots[entry.value] ??= Queue<int>()).add(entry.key);
      }
      final desired = entries.values.map((entry) => entry.node).toSet();
      for (final entry in entries.entries) {
        final index = entry.key, target = entry.value, node = target.node;
        final builder = target.builder;
        final selection = widget.controller.state.selection;
        final width = target.width;
        final position = target.position;
        final slots = previousSlots[node];
        int? previous = slots == null || slots.isEmpty
            ? null
            : slots.removeFirst();
        if (previous == null &&
            remaining.containsKey(index) &&
            _viewNodes[index]?.type == node.type &&
            !desired.contains(_viewNodes[index])) {
          previous = index;
        }
        final selected =
            !widget.readOnly &&
            selection is m.NodeSelection &&
            selection.from == position;
        final cached = _viewWidgets[previous];
        final reuse =
            cached != null &&
            identical(cached.view.node, node) &&
            cached.view.position == position &&
            cached.view.selected == selected &&
            cached.view.width == width &&
            cached.builder == builder;
        final view = reuse
            ? cached.view
            : TiptapNodeView(
                node: node,
                position: position,
                selected: selected,
                width: width,
                updateAttrs: (attrs) {
                  // A delayed host callback must not update a different node after an edit.
                  if (!identical(
                        widget.controller.state.doc.nodeAt(position),
                        node,
                      ) ||
                      widget.readOnly) {
                    return;
                  }
                  final tr = widget.controller.state.tr;
                  for (final entry in attrs.entries) {
                    tr.step(m.AttrStep(position, entry.key, entry.value));
                  }
                  widget.controller.apply(tr);
                },
              );
        final child = reuse
            ? cached.child
            : Builder(builder: (context) => builder(context, view));
        final old = previous == null ? null : remaining.remove(previous);
        final element = updateChild(old, child, index);
        if (element != null) {
          nextChildren[index] = element;
          nextNodes[index] = node;
          nextWidgets[index] = (view: view, builder: builder, child: child);
        }
      }
      for (final entry in remaining.entries) {
        updateChild(entry.value, null, entry.value.slot);
      }
      _children
        ..clear()
        ..addAll(nextChildren);
      _viewNodes
        ..clear()
        ..addAll(nextNodes);
      _viewWidgets
        ..clear()
        ..addAll(nextWidgets);
    });
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    _children.values.forEach(visitor);
    _chromeChildren.values.forEach(visitor);
  }

  @override
  void forgetChild(Element child) {
    _children.removeWhere((_, value) => identical(child, value));
    _chromeChildren.removeWhere((_, value) => identical(child, value));
    super.forgetChild(child);
  }

  @override
  void insertRenderObjectChild(RenderObject child, Object? slot) {
    renderObject.insert(child as RenderBox);
    (child.parentData! as _NodeViewParentData).row = slot! as int;
  }

  @override
  void moveRenderObjectChild(
    RenderObject child,
    Object? oldSlot,
    Object? newSlot,
  ) {
    (child.parentData! as _NodeViewParentData).row = newSlot! as int;
  }

  @override
  void removeRenderObjectChild(RenderObject child, Object? slot) =>
      renderObject.remove(child as RenderBox);
}

extension _NodeViewLayout on _RenderEditorViewport {
  void _measureChrome() {
    final oldTop = _contentTop;
    var child = firstChild;
    _headerHeight = 0;
    _footerHeight = 0;
    while (child != null) {
      final data = child.parentData! as _NodeViewParentData;
      if (data.row < 0) {
        child.layout(
          BoxConstraints.tightFor(width: _contentWidth),
          parentUsesSize: true,
        );
        if (data.row == -1) {
          _headerHeight = child.size.height;
        } else {
          _footerHeight = child.size.height;
        }
      }
      child = data.nextSibling;
    }
    if (_offset.pixels > oldTop && (_contentTop - oldTop).abs() > .01) {
      _correctScroll(_contentTop - oldTop);
    }
  }

  Map<int, _ViewTarget> _visibleViews(Set<int> visible) {
    final result = <int, _ViewTarget>{};
    for (final index in visible) {
      for (final block in _contentBlocks(index)) {
        final node = block.layout.node, builder = _viewBuilderFor(node);
        if (builder == null) continue;
        final width = _widthFor(node, block.width);
        final (origin, _) = _mediaBox(
          node,
          block.origin,
          block.width,
          measured: block.cellRow == null,
          clampCenter: block.cellRow == null,
        );
        final code = node.type == 'codeBlock';
        result[block.absolutePosition] = _ViewTarget(
          node,
          block.absolutePosition,
          index,
          width,
          origin,
          table: block.cellRow != null,
          builder: builder,
          constraints: code
              ? BoxConstraints.tightFor(
                  width: math.max(1, width - 16),
                  height: math.max(24, _style.codeBlockPadding.top - 10),
                )
              : _style.centerMedia
              ? BoxConstraints(maxWidth: width)
              : BoxConstraints.tightFor(width: width),
          offset: code ? const Offset(8, 2) : Offset.zero,
        );
      }
    }
    return result;
  }

  TiptapNodeViewBuilder? _viewBuilderFor(m.Node node) =>
      node.type == 'codeBlock' ? _codeBlockHeader : _nodeViews[node.type];

  (Offset, double) _mediaBox(
    m.Node node,
    Offset origin,
    double available, {
    bool measured = false,
    bool clampCenter = false,
  }) {
    final requested = _widthFor(node, available);
    final width = measured
        ? _nodeSizes.get(node, requested)?.width ?? requested
        : requested;
    var inset = _style.centerMedia && m.isResizableMedia(node)
        ? (available - width) / 2
        : 0.0;
    if (clampCenter) inset = math.max(0, inset);
    return (origin + Offset(inset, 0), width);
  }

  double _widthFor(
    m.Node node,
    double available, {
    bool clampWidth = true,
    bool usePreview = true,
  }) {
    final preview = usePreview ? _controller._widthPreview : null;
    final width =
        available *
        m.mediaWidthFactor(
          node,
          preview: identical(preview?.node, node) ? preview!.percent : null,
        );
    return clampWidth ? math.max(1, width) : width;
  }

  Set<int> _visibleNodeRows() {
    final visible = <int>{};
    for (
      var index = _firstVisible;
      index < math.min(_lastVisible, _doc.rowCount);
      index++
    ) {
      if ((_row(index).node.type == 'tableRow' ||
              _viewBuilderFor(_row(index).node) != null) &&
          _rowOrigin(index).dy < size.height &&
          _rowOrigin(index).dy + _heights!.heightAt(index) >= 0) {
        visible.add(index);
      }
    }
    return visible;
  }

  bool _layoutNodeViews() {
    final visible = _visibleNodeRows();
    final targets = _visibleViews(visible);
    _buildNodeViews(targets);
    var child = firstChild;
    final tables = <int>{};
    while (child != null) {
      final data = child.parentData! as _NodeViewParentData;
      if (data.row < 0) {
        child = data.nextSibling;
        continue;
      }
      final target = targets[data.row]!;
      data.position = target.position;
      final code = target.node.type == 'codeBlock';
      child.layout(target.constraints, parentUsesSize: true);
      if (!code) {
        final height = child.size.height;
        final changed =
            _nodeSizes.get(target.node, target.width)?.height != height ||
            _layouts[target.node]?.height != height;
        _nodeSizes.put(target.node, target.width, child.size);
        _layouts[target.node]?.height = height;
        if (target.table) {
          if (changed) {
            final cached = _layouts[target.node];
            if (cached != null) _invalidateTableUsers(cached);
            final row = _row(target.row),
                layout = _layouts[_row(target.row).node] as _TableRowLayout;
            for (final (block, cell) in layout.contentRows()) {
              if (!identical(block.layout.node, target.node)) continue;
              for (
                var rowIndex = cell.grid.top;
                rowIndex < cell.grid.bottom;
                rowIndex++
              ) {
                tables.add(target.row - row.tableRow + rowIndex);
              }
            }
          }
        } else {
          _measureRow(target.row, height + _spacing(target.row));
        }
      }
      child = data.nextSibling;
    }
    for (final index in tables) {
      // A row's height depends on all mounted media in its cells.
      (_layouts[_row(index).node] as _TableRowLayout?)?.invalidate();
      _layoutBlock(index);
    }
    return setEquals(visible, _visibleNodeRows());
  }

  void _positionNodeViews() {
    final targets = _visibleViews(_visibleNodeRows());
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as _NodeViewParentData;
      final target = targets[data.row];
      data.offset = data.row == -1
          ? Offset(_style.padding.left, _style.padding.top - _offset.pixels)
          : data.row == -2
          ? Offset(
              _style.padding.left,
              _contentTop + _heights!.totalHeight - _offset.pixels,
            )
          : target == null
          ? Offset.zero
          : target.origin + target.offset;
      child = data.nextSibling;
    }
  }
}

class _ViewTarget {
  const _ViewTarget(
    this.node,
    this.position,
    this.row,
    this.width,
    this.origin, {
    this.table = false,
    required this.builder,
    required this.constraints,
    required this.offset,
  });
  final m.Node node;
  final int position, row;
  final double width;
  final Offset origin;
  final bool table;
  final TiptapNodeViewBuilder builder;
  final BoxConstraints constraints;
  final Offset offset;
}
