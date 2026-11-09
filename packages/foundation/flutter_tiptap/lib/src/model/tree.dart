part of '../model.dart';

class _MarkCoverage {
  const _MarkCoverage(this.length, this.marks);
  static const zero = _MarkCoverage(0, {});
  final int length;
  final Map<String, int> marks;
  _MarkCoverage operator +(_MarkCoverage b) {
    if (length == 0) return b;
    if (b.length == 0) return this;
    final values = {...marks};
    for (final entry in b.marks.entries) {
      values.update(
        entry.key,
        (v) => v + entry.value,
        ifAbsent: () => entry.value,
      );
    }
    return _MarkCoverage(length + b.length, Map.unmodifiable(values));
  }
}

class BlockSummary {
  const BlockSummary._(
    this.nodeSize,
    this.textLength,
    this.blockCount,
    this.headingCount,
    this.rowCount,
    this._marks,
    this.blockType,
    this.headingLevel,
  );
  static const zero = BlockSummary._(
    0,
    0,
    0,
    0,
    0,
    _MarkCoverage.zero,
    null,
    null,
  );
  final int nodeSize;
  final int textLength;
  final int blockCount;
  final int headingCount;
  final int rowCount;
  final _MarkCoverage _marks;
  final String? blockType;
  final int? headingLevel;
  BlockSummary operator +(BlockSummary b) {
    if (blockCount == 0) return b;
    if (b.blockCount == 0) return this;
    return BlockSummary._(
      nodeSize + b.nodeSize,
      textLength + b.textLength,
      blockCount + b.blockCount,
      headingCount + b.headingCount,
      rowCount + b.rowCount,
      _marks + b._marks,
      blockType == b.blockType ? blockType : null,
      headingLevel == b.headingLevel ? headingLevel : null,
    );
  }
}

class _Tree {
  _Tree.leaf(Node value)
    : node = value,
      left = null,
      right = null,
      height = 1,
      summary = BlockSummary._(
        value.nodeSize,
        value.textLength,
        1,
        value.type == 'heading' ? 1 : 0,
        value.rowCount,
        value._markCoverage,
        value.isTextblock
            ? value.type
            : value.content.blocks?.summary.blockType,
        value.type == 'heading'
            ? value.attrs['level'] as int?
            : value.content.blocks?.summary.headingLevel,
      );
  _Tree.branch(_Tree a, _Tree b)
    : node = null,
      left = a,
      right = b,
      height = 1 + math.max(a.height, b.height),
      summary = a.summary + b.summary;
  final Node? node;
  final _Tree? left;
  final _Tree? right;
  final int height;
  final BlockSummary summary;
}

_Tree? _join(_Tree? a, _Tree? b) {
  if (a == null) return b;
  if (b == null) return a;
  if (a.height > b.height + 1) return _balance(a.left!, _join(a.right, b)!);
  if (b.height > a.height + 1) return _balance(_join(a, b.left)!, b.right!);
  return _Tree.branch(a, b);
}

_Tree _balance(_Tree a, _Tree b) {
  if (a.height > b.height + 1) {
    final l = a.left!, r = a.right!;
    if (l.height >= r.height) return _Tree.branch(l, _Tree.branch(r, b));
    return _Tree.branch(_Tree.branch(l, r.left!), _Tree.branch(r.right!, b));
  }
  if (b.height > a.height + 1) {
    final l = b.left!, r = b.right!;
    if (r.height >= l.height) return _Tree.branch(_Tree.branch(a, l), r);
    return _Tree.branch(_Tree.branch(a, l.left!), _Tree.branch(l.right!, r));
  }
  return _Tree.branch(a, b);
}

(_Tree?, _Tree?) _split(_Tree? tree, int index) {
  if (tree == null) return (null, null);
  if (index == 0) return (null, tree);
  if (index == tree.summary.blockCount) return (tree, null);
  final leftCount = tree.left!.summary.blockCount;
  if (index < leftCount) {
    final (a, b) = _split(tree.left, index);
    return (a, _join(b, tree.right));
  }
  final (a, b) = _split(tree.right, index - leftCount);
  return (_join(tree.left, a), b);
}

_Tree? _buildTree(List<Node> nodes, int start, int end) {
  if (start == end) return null;
  if (end == start + 1) return _Tree.leaf(nodes[start]);
  final mid = (start + end) ~/ 2;
  return _Tree.branch(
    _buildTree(nodes, start, mid)!,
    _buildTree(nodes, mid, end)!,
  );
}

class BlockTree extends Iterable<Node> {
  const BlockTree._(this._root);
  factory BlockTree(Iterable<Node> nodes) {
    if (nodes is BlockTree) return nodes;
    if (nodes is Fragment && nodes.blocks != null) return nodes.blocks!;
    final list = nodes.toList(growable: false);
    return BlockTree._(_buildTree(list, 0, list.length));
  }
  final _Tree? _root;
  BlockSummary get summary => _root?.summary ?? BlockSummary.zero;
  int get height => _root?.height ?? 0;
  @override
  int get length => summary.blockCount;
  @override
  bool get isEmpty => length == 0;
  @override
  Node get first => isEmpty ? throw StateError('No element') : this[0];
  @override
  Node get last => isEmpty ? throw StateError('No element') : this[length - 1];
  @override
  Node elementAt(int index) => this[index];
  Node operator [](int index) {
    RangeError.checkValidIndex(index, this, 'index', length);
    var tree = _root!;
    while (tree.node == null) {
      final count = tree.left!.summary.blockCount;
      if (index < count) {
        tree = tree.left!;
      } else {
        index -= count;
        tree = tree.right!;
      }
    }
    return tree.node!;
  }

  int positionAt(int index) {
    RangeError.checkValueInInterval(index, 0, length, 'index');
    if (index == length) return summary.nodeSize;
    var tree = _root!;
    var pos = 0;
    while (tree.node == null) {
      final count = tree.left!.summary.blockCount;
      if (index < count) {
        tree = tree.left!;
      } else {
        index -= count;
        pos += tree.left!.summary.nodeSize;
        tree = tree.right!;
      }
    }
    return pos;
  }

  /// At a block boundary, returns the block on the right; at doc end, length.
  int indexAt(int position) {
    RangeError.checkValueInInterval(position, 0, summary.nodeSize, 'position');
    if (position == summary.nodeSize) return length;
    var tree = _root!;
    var index = 0;
    while (tree.node == null) {
      final size = tree.left!.summary.nodeSize;
      if (position < size) {
        tree = tree.left!;
      } else {
        position -= size;
        index += tree.left!.summary.blockCount;
        tree = tree.right!;
      }
    }
    return index;
  }

  BlockSummary summaryBetween(int from, int to) {
    RangeError.checkValueInInterval(from, 0, length, 'from');
    RangeError.checkValueInInterval(to, from, length, 'to');
    BlockSummary visit(_Tree? tree, int offset) {
      if (tree == null ||
          to <= offset ||
          from >= offset + tree.summary.blockCount) {
        return BlockSummary.zero;
      }
      if (from <= offset && to >= offset + tree.summary.blockCount) {
        return tree.summary;
      }
      return visit(tree.left, offset) +
          visit(tree.right, offset + (tree.left?.summary.blockCount ?? 0));
    }

    return visit(_root, 0);
  }

  /// Count of editable/atom rows before a child index.
  int rowsBefore(int index) => summaryBetween(0, index).rowCount;

  /// Child containing a row, and that child's first row index.
  (int, int) childForRow(int row) {
    RangeError.checkValueInInterval(row, 0, summary.rowCount - 1, 'row');
    var tree = _root!, index = 0, before = 0;
    while (tree.node == null) {
      final count = tree.left!.summary.rowCount;
      if (row < count) {
        tree = tree.left!;
      } else {
        row -= count;
        before += count;
        index += tree.left!.summary.blockCount;
        tree = tree.right!;
      }
    }
    return (index, before);
  }

  BlockTree slice(int from, int to) {
    RangeError.checkValueInInterval(from, 0, length, 'from');
    RangeError.checkValueInInterval(to, from, length, 'to');
    final (_, rest) = _split(_root, from);
    final (middle, _) = _split(rest, to - from);
    return BlockTree._(middle);
  }

  BlockTree replace(int from, int to, Iterable<Node> nodes) {
    RangeError.checkValueInInterval(from, 0, length, 'from');
    RangeError.checkValueInInterval(to, from, length, 'to');
    final (a, rest) = _split(_root, from);
    final (_, b) = _split(rest, to - from);
    return BlockTree._(_join(_join(a, BlockTree(nodes)._root), b));
  }

  Iterable<Node> _walk(_Tree? tree) sync* {
    if (tree == null) return;
    if (tree.node case final node?) {
      yield node;
    } else {
      yield* _walk(tree.left);
      yield* _walk(tree.right);
    }
  }

  @override
  Iterator<Node> get iterator => _walk(_root).iterator;
}
