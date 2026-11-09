part of '../editor.dart';

class _HeightNode {
  _HeightNode.leaf(this.node, this.base, this.weight)
    : left = null,
      right = null,
      count = 1,
      depth = 1;
  _HeightNode.branch(_HeightNode a, _HeightNode b, double width, int generation)
    : node = null,
      left = a,
      right = b,
      count = a.count + b.count,
      depth = 1 + math.max(a.depth, b.depth),
      base = a.base + b.base,
      weight = a.weight + b.weight {
    measuredGeneration = generation;
    measured = a.sum(width, generation) + b.sum(width, generation);
  }
  final m.Node? node;
  final _HeightNode? left, right;
  final int count, depth;
  final double base, weight;
  int measuredGeneration = -1;
  double measured = 0;
  double sum(double width, int generation) =>
      measuredGeneration == generation ? measured : base + weight / width;
}

/// Tracks estimated row heights and maps vertical offsets to row indices.
class TiptapHeightIndex {
  TiptapHeightIndex(
    Iterable<m.Node> blocks, {
    required this.style,
    double width = 400,
    this.estimateHeight,
  }) : _width = math.max(1, width) {
    final nodes = blocks.map(_leaf).toList(growable: false);
    _root = _build(nodes, 0, nodes.length);
  }
  final TiptapEditorStyle style;
  final TiptapNodeHeightEstimator? estimateHeight;
  _HeightNode? _root;
  double _width;
  int _generation = 0;
  int get length => _root?.count ?? 0;
  double get totalHeight => _sum(_root);
  double get width => _width;
  void setWidth(double width) {
    width = math.max(1, width);
    if (_width == width) return;
    _width = width;
    _generation++;
  }

  _HeightNode _leaf(m.Node node) {
    if (node.type == 'tableRow') return _HeightNode.leaf(node, 42, 0);
    if (!node.isTextblock) {
      return _HeightNode.leaf(
        node,
        (estimateHeight?.call(node, _width) ?? style.opaqueBlockHeight) +
            style.blockSpacing,
        0,
      );
    }
    final text = style.forBlock(node), font = text.fontSize ?? 17;
    final line = font * (text.height ?? 1.5);
    return _HeightNode.leaf(
      node,
      line + style.blockSpacing,
      node.content.size * font * .65 * line,
    );
  }

  double _sum(_HeightNode? node) => node?.sum(_width, _generation) ?? 0;
  _HeightNode _branch(_HeightNode a, _HeightNode b) =>
      _HeightNode.branch(a, b, _width, _generation);
  _HeightNode? _build(List<_HeightNode> list, int start, int end) {
    if (start == end) return null;
    if (end == start + 1) return list[start];
    final mid = (start + end) ~/ 2;
    return _branch(_build(list, start, mid)!, _build(list, mid, end)!);
  }

  _HeightNode? _join(_HeightNode? a, _HeightNode? b) {
    if (a == null) return b;
    if (b == null) return a;
    if (a.depth > b.depth + 1) return _balance(a.left!, _join(a.right, b)!);
    if (b.depth > a.depth + 1) return _balance(_join(a, b.left)!, b.right!);
    return _branch(a, b);
  }

  _HeightNode _balance(_HeightNode a, _HeightNode b) {
    if (a.depth > b.depth + 1) {
      final l = a.left!, r = a.right!;
      if (l.depth >= r.depth) return _branch(l, _branch(r, b));
      return _branch(_branch(l, r.left!), _branch(r.right!, b));
    }
    if (b.depth > a.depth + 1) {
      final l = b.left!, r = b.right!;
      if (r.depth >= l.depth) return _branch(_branch(a, l), r);
      return _branch(_branch(a, l.left!), _branch(l.right!, r));
    }
    return _branch(a, b);
  }

  (_HeightNode?, _HeightNode?) _split(_HeightNode? node, int index) {
    if (node == null) return (null, null);
    if (index == 0) return (null, node);
    if (index == node.count) return (node, null);
    final leftCount = node.left!.count;
    if (index < leftCount) {
      final (a, b) = _split(node.left, index);
      return (a, _join(b, node.right));
    }
    final (a, b) = _split(node.right, index - leftCount);
    return (_join(node.left, a), b);
  }

  double offsetOf(int index) {
    RangeError.checkValueInInterval(index, 0, length, 'index');
    if (index == length) return totalHeight;
    var node = _root!, offset = 0.0;
    while (node.node == null) {
      final count = node.left!.count;
      if (index < count) {
        node = node.left!;
      } else {
        index -= count;
        offset += _sum(node.left);
        node = node.right!;
      }
    }
    return offset;
  }

  int indexAt(double offset) {
    if (_root == null) return 0;
    offset = offset.clamp(0, totalHeight);
    var node = _root!, index = 0;
    while (node.node == null) {
      final size = _sum(node.left);
      if (offset < size) {
        node = node.left!;
      } else {
        offset -= size;
        index += node.left!.count;
        node = node.right!;
      }
    }
    return index;
  }

  double heightAt(int index) => offsetOf(index + 1) - offsetOf(index);
  void measure(int index, double height) {
    RangeError.checkValueInInterval(index, 0, length - 1, 'index');
    if (!height.isFinite || height <= 0) {
      throw ArgumentError.value(height, 'height');
    }
    void visit(_HeightNode node, int index) {
      if (node.node != null) {
        node.measured = height;
        node.measuredGeneration = _generation;
        return;
      }
      if (index < node.left!.count) {
        visit(node.left!, index);
      } else {
        visit(node.right!, index - node.left!.count);
      }
      node.measuredGeneration = _generation;
      node.measured = _sum(node.left) + _sum(node.right);
    }

    visit(_root!, index);
  }

  void replace(int from, int to, Iterable<m.Node> blocks) {
    RangeError.checkValueInInterval(from, 0, length, 'from');
    RangeError.checkValueInInterval(to, from, length, 'to');
    final list = blocks.map(_leaf).toList(growable: false);
    if (list.length == to - from) {
      for (var i = 0; i < list.length; i++) {
        list[i].measuredGeneration = _generation;
        list[i].measured = heightAt(from + i);
      }
    }
    final (a, rest) = _split(_root, from);
    final (_, b) = _split(rest, to - from);
    _root = _join(_join(a, _build(list, 0, list.length)), b);
  }
}
