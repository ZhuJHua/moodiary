part of '../editor.dart';

class _NodeSizeKey {
  const _NodeSizeKey(this.node, this.width);

  final m.Node node;
  final double width;

  @override
  bool operator ==(Object other) =>
      other is _NodeSizeKey &&
      width == other.width &&
      identical(node, other.node);

  @override
  int get hashCode => Object.hash(identityHashCode(node), width);
}

class _MeasuredSizes {
  _MeasuredSizes(this.diagnostics);
  final TiptapDiagnostics Function() diagnostics;
  late final _sizes = _LruMap<_NodeSizeKey, Size>(
    512,
    onEvict: (key, _) {
      final media = _mediaKey(key.node, key.width), entries = _media[media];
      entries?.remove(key);
      if (entries?.isEmpty == true) _media.remove(media);
    },
  );
  final _media = <(String, Object?, Object?, double), Set<_NodeSizeKey>>{};
  (String, Object?, Object?, double) _mediaKey(m.Node node, double width) =>
      (node.type, node.attrs['src'], node.attrs['widthPercent'], width);

  Size? get(m.Node node, double width) {
    final cached = _sizes[_NodeSizeKey(node, width)];
    if (cached != null) return cached;
    if (!node.isLeaf) return null;
    Size? equivalent;
    final candidates = m.isMediaNode(node)
        ? _media[_mediaKey(node, width)] ?? const <_NodeSizeKey>{}
        : _sizes.entries.map((entry) => entry.key).toList(growable: false);
    for (final key in candidates) {
      diagnostics().measurementComparisons++;
      if (key.width != width || !key.node.eq(node)) continue;
      final size = _sizes[key]!;
      if (equivalent != null && equivalent != size) return null;
      equivalent = size;
    }
    return equivalent;
  }

  void put(m.Node node, double width, Size size) {
    final key = _NodeSizeKey(node, width);
    _sizes[key] = size;
    if (node.isLeaf && m.isMediaNode(node)) {
      (_media[_mediaKey(node, width)] ??= {}).add(key);
    }
  }

  void carry(m.Node before, m.Node after) {
    if (identical(before, after) || !before.isLeaf || !before.eq(after)) return;
    final measurements = _sizes.entries
        .where((entry) => identical(entry.key.node, before))
        .toList();
    for (final entry in measurements) {
      put(after, entry.key.width, entry.value);
    }
  }

  void clear() {
    _sizes.clear();
    _media.clear();
  }

  void invalidate(Set<m.Node> nodes) {
    final sources = {for (final node in nodes) (node.type, node.attrs['src'])};
    final keys = _sizes.entries
        .map((entry) => entry.key)
        .where(
          (key) => sources.contains((key.node.type, key.node.attrs['src'])),
        )
        .toList();
    for (final key in keys) {
      _sizes.remove(key);
      final media = _mediaKey(key.node, key.width), entries = _media[media];
      entries?.remove(key);
      if (entries?.isEmpty == true) _media.remove(media);
    }
  }
}

extension _LayoutCache on _RenderEditorViewport {
  void _invalidateTableUsers(
    _BlockLayout layout, [
    Set<_TableRowLayout>? visited,
  ]) {
    final seen = visited ?? <_TableRowLayout>{};
    for (final table in layout.tableUsers) {
      if (!seen.add(table)) continue;
      table.invalidate();
      _invalidateTableUsers(table, seen);
    }
  }

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
          _touchLayout(block.layout);
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
    if (_layouts.length <= _RenderEditorViewport._layoutLimit &&
        _cachedTextLength <= _RenderEditorViewport._layoutTextLimit) {
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
          protected.addAll(cell.blocks.map((block) => block.layout));
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
      if (_horizontal._horizontalBlockPosition case final position?) {
        protect(_indexForPosition(position));
      }
    }
    var removed = true;
    while (removed &&
        (_layouts.length > _RenderEditorViewport._layoutLimit ||
            _cachedTextLength > _RenderEditorViewport._layoutTextLimit)) {
      removed = false;
      for (final layout in _layoutOrder.toList()) {
        if (_layouts.length <= _RenderEditorViewport._layoutLimit &&
            _cachedTextLength <= _RenderEditorViewport._layoutTextLimit) {
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

  void _invalidateLayout({
    bool heights = false,
    bool styles = false,
    bool fonts = false,
  }) {
    _clearLayouts();
    _visibleLayouts.clear();
    _nodeSizes.clear();
    if (heights) {
      _heights = null;
      _rows.clear();
    }
    if (styles) _highlights = Expando<TextSpan>();
    if (styles || fonts) {
      _chrome = Expando<_LruMap<String, ui.Paragraph>>();
      _placeholderParagraph = null;
    }
    if (fonts) {
      _orderedGutters = Expando();
      _lastOrderedGutters = Expando();
      _columnSizes = Expando();
      _tableGeometries = Expando();
    }
  }
}
