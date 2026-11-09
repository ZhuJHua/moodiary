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
    if (!mapEquals(old.nodeViews, newWidget.nodeViews) ||
        old.nodeHeightEstimator != newWidget.nodeHeightEstimator) {
      renderObject.markNeedsLayout();
    }
  }

  void _buildVisible(Set<int> visible) {
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
          nextNodes = <int, m.Node>{};
      final entries = renderObject._visibleViews(visible);
      final desired = entries.values.map((entry) => entry.node).toSet();
      for (final entry in entries.entries) {
        final index = entry.key, target = entry.value, node = target.node;
        final builder = node.type == 'codeBlock'
            ? widget.codeBlockHeader
            : widget.nodeViews[node.type];
        if (builder == null) continue;
        final selection = widget.controller.state.selection;
        final width = target.width;
        final position = target.position;
        final view = TiptapNodeView(
          node: node,
          position: position,
          selected:
              !widget.readOnly &&
              selection is m.NodeSelection &&
              selection.from == position,
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
        final child = Builder(builder: (context) => builder(context, view));
        int? previous;
        for (final entry in remaining.entries) {
          if (identical(_viewNodes[entry.key], node)) {
            previous = entry.key;
            break;
          }
        }
        if (previous == null &&
            remaining.containsKey(index) &&
            _viewNodes[index]?.type == node.type &&
            !desired.contains(_viewNodes[index])) {
          previous = index;
        }
        final old = previous == null ? null : remaining.remove(previous);
        final element = updateChild(old, child, index);
        if (element != null) {
          nextChildren[index] = element;
          nextNodes[index] = node;
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
      _offset.correctBy(_contentTop - oldTop);
    }
  }

  Map<int, _ViewTarget> _visibleViews(Set<int> visible) {
    final result = <int, _ViewTarget>{};
    for (final index in visible) {
      final row = _row(index), layout = _layoutBlock(index);
      if (layout is _TableRowLayout) {
        for (final cell in layout.cells) {
          for (final block in cell.blocks) {
            final node = block.$1.node;
            if (!_nodeViews.containsKey(node.type) &&
                !(node.type == 'codeBlock' && _codeBlockHeader != null)) {
              continue;
            }
            final position = row.position + block.$2;
            final available = cell.rect.width - 20;
            final width = _widthFor(node, available);
            final point =
                _origin(index) +
                layout._blockOrigin(cell, block.$3) +
                Offset(
                  _style.centerMedia &&
                          const {'image', 'video'}.contains(node.type)
                      ? (available - width) / 2
                      : 0,
                  0,
                );
            result[position] = _ViewTarget(
              node,
              position,
              index,
              width,
              point,
              table: true,
            );
          }
        }
      } else if (_nodeViews.containsKey(row.node.type) ||
          row.node.type == 'codeBlock' && _codeBlockHeader != null) {
        result[row.position] = _ViewTarget(
          row.node,
          row.position,
          index,
          _nodeWidth(index),
          _nodeOrigin(index),
        );
      }
    }
    return result;
  }

  double _widthFor(m.Node node, double available) {
    final preview = _controller._widthPreview;
    final percent = identical(preview?.node, node)
        ? preview!.percent
        : node.attrs['widthPercent'];
    return math.max(
      1,
      available * (percent is num ? percent.clamp(25, 100) / 100 : 1),
    );
  }

  Offset _nodeOrigin(int index) {
    final row = _row(index), width = _nodeWidths[row.node] ?? _nodeWidth(index);
    return _rowOrigin(index) +
        Offset(
          _style.centerMedia && const {'image', 'video'}.contains(row.node.type)
              ? math.max(0, (_contentWidth - row.indent - width) / 2)
              : 0,
          0,
        );
  }

  double _nodeWidth(int index) {
    return _widthFor(_row(index).node, _contentWidth - _row(index).indent);
  }

  Set<int> _visibleNodeRows() {
    final visible = <int>{};
    for (
      var index = _firstVisible;
      index < math.min(_lastVisible, _doc.rowCount);
      index++
    ) {
      if ((_row(index).node.type == 'tableRow' ||
              _nodeViews.containsKey(_row(index).node.type) ||
              _row(index).node.type == 'codeBlock' &&
                  _codeBlockHeader != null) &&
          _rowOrigin(index).dy < size.height &&
          _rowOrigin(index).dy + _heights!.heightAt(index) >= 0) {
        visible.add(index);
      }
    }
    return visible;
  }

  bool _layoutNodeViews() {
    final visible = _visibleNodeRows();
    _buildNodeViews(visible);
    final targets = _visibleViews(visible);
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
      child.layout(
        code
            ? BoxConstraints.tightFor(
                width: math.max(1, target.width - 16),
                height: math.max(24, _style.codeBlockPadding.top - 10),
              )
            : _style.centerMedia
            ? BoxConstraints(maxWidth: target.width)
            : BoxConstraints.tightFor(width: target.width),
        parentUsesSize: true,
      );
      if (!code) {
        _nodeWidths[target.node] = child.size.width;
        final height = child.size.height;
        final changed = _nodeSizes[target.node] != height;
        _nodeSizes[target.node] = height;
        _layouts[target.node]?.height = height;
        if (target.table) {
          if (changed) {
            final row = _row(target.row),
                layout = _layouts[_row(target.row).node] as _TableRowLayout;
            for (final cell in layout.cells) {
              if (!cell.blocks.any(
                (block) => identical(block.$1.node, target.node),
              )) {
                continue;
              }
              for (var r = cell.grid.top; r < cell.grid.bottom; r++) {
                tables.add(target.row - row.tableRow + r);
              }
            }
          }
        } else {
          final heights = _heights!,
              anchor = heights.indexAt(
                math.max(0, _offset.pixels - _contentTop),
              );
          final before = heights.offsetOf(anchor);
          heights.measure(target.row, height + _spacing(target.row));
          if (target.row < anchor) {
            _offset.correctBy(heights.offsetOf(anchor) - before);
          }
        }
      }
      child = data.nextSibling;
    }
    for (final index in tables) {
      // A row's height depends on all mounted media in its cells.
      (_layouts[_row(index).node] as _TableRowLayout?)?.width = null;
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
          : target.origin +
                (target.node.type == 'codeBlock'
                    ? const Offset(8, 2)
                    : Offset.zero);
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
  });
  final m.Node node;
  final int position, row;
  final double width;
  final Offset origin;
  final bool table;
}
