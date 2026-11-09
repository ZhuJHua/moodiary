part of '../model.dart';

/// A document selection whose positions can be mapped through editing steps.
sealed class Selection {
  const Selection(this.anchor, this.head);
  final int anchor;
  final int head;
  int get from => math.min(anchor, head);
  int get to => math.max(anchor, head);
  bool get empty => from == to;
  static Selection near(Node doc, int position, {int bias = 1}) {
    final resolved = doc.resolve(position);
    if (resolved.parent.isTextblock) return TextSelection(position);
    Selection? search(Node node, int start, int direction) {
      if (node.isTextblock) {
        return TextSelection(start + (direction > 0 ? 0 : node.content.size));
      }
      if (node.isLeaf) return NodeSelection(doc, start - 1);
      for (
        var i = direction > 0 ? 0 : node.childCount - 1;
        i >= 0 && i < node.childCount;
        i += direction
      ) {
        final found = search(
          node.child(i),
          start + node.content.positionAt(i) + 1,
          direction,
        );
        if (found != null) return found;
      }
      return null;
    }

    for (final direction in [bias >= 0 ? 1 : -1, bias >= 0 ? -1 : 1]) {
      for (var d = resolved.depth; d >= 0; d--) {
        final parent = resolved.node(d);
        var i = direction > 0 ? resolved.indexAfter(d) : resolved.index(d) - 1;
        for (; i >= 0 && i < parent.childCount; i += direction) {
          final found = search(
            parent.child(i),
            resolved.start(d) + parent.content.positionAt(i) + 1,
            direction,
          );
          if (found != null) return found;
        }
      }
    }
    return AllSelection(doc);
  }

  /// A text caret beside a block, or an insertable gap in its own container.
  static Selection beside(Node doc, int position, {int bias = 1}) {
    final pos = doc.resolve(position);
    if (pos.parent.isTextblock) return TextSelection(position);
    final neighbor = bias < 0 ? pos.nodeBefore : pos.nodeAfter;
    if (neighbor?.isTextblock == true) {
      return TextSelection(bias < 0 ? position - 1 : position + 1);
    }
    final paragraph = doc.schema.node('paragraph');
    if (pos.parent.canReplace(
      pos.index(),
      pos.index(),
      Fragment([paragraph]),
    )) {
      return GapSelection(position);
    }
    return near(doc, position, bias: bias);
  }

  Selection map(Node doc, Mapping mapping);
  @override
  bool operator ==(Object other) =>
      other is Selection &&
      runtimeType == other.runtimeType &&
      anchor == other.anchor &&
      head == other.head;
  @override
  int get hashCode => Object.hash(runtimeType, anchor, head);
}

class TextSelection extends Selection {
  const TextSelection(int anchor, [int? head]) : super(anchor, head ?? anchor);
  @override
  Selection map(Node doc, Mapping mapping) {
    final headPosition = mapping.map(head).clamp(0, doc.content.size),
        anchorPosition = mapping.map(anchor).clamp(0, doc.content.size);
    if (!doc.resolve(headPosition).parent.isTextblock) {
      return Selection.near(doc, headPosition);
    }
    return TextSelection(
      doc.resolve(anchorPosition).parent.isTextblock
          ? anchorPosition
          : headPosition,
      headPosition,
    );
  }
}

/// An insertion caret between blocks, including document and cell edges.
class GapSelection extends Selection {
  const GapSelection(int position) : super(position, position);
  @override
  Selection map(Node doc, Mapping mapping) {
    final p = mapping.map(head).clamp(0, doc.content.size);
    return doc.resolve(p).parent.isTextblock
        ? TextSelection(p)
        : GapSelection(p);
  }
}

class NodeSelection extends Selection {
  NodeSelection(Node doc, int position)
    : super(position, position + doc.nodeAt(position)!.nodeSize);
  @override
  Selection map(Node doc, Mapping mapping) {
    final result = mapping.mapResult(anchor);
    return result.deleted || result.pos == doc.content.size
        ? TextSelection(result.pos)
        : NodeSelection(doc, result.pos);
  }
}

class AllSelection extends Selection {
  AllSelection(Node doc) : super(0, doc.content.size);
  @override
  AllSelection map(Node doc, Mapping mapping) => AllSelection(doc);
}

class MapResult {
  const MapResult(this.pos, this.deleted);
  final int pos;
  final bool deleted;
}

class StepMap {
  const StepMap(this.from, this.oldSize, this.newSize) : _ranges = null;
  StepMap.ranges(List<(int, int, int)> ranges)
    : _ranges = List.unmodifiable(ranges),
      from = ranges.first.$1,
      oldSize = ranges.last.$1 + ranges.last.$2 - ranges.first.$1,
      newSize =
          ranges.last.$1 +
          ranges.last.$2 -
          ranges.first.$1 +
          ranges.fold(0, (n, r) => n + r.$3 - r.$2);
  final List<(int, int, int)>? _ranges;
  static const empty = StepMap(0, 0, 0);
  final int from;
  final int oldSize;
  final int newSize;
  int map(int position, [int assoc = 1]) => mapResult(position, assoc).pos;
  MapResult mapResult(int pos, [int assoc = 1]) {
    if (_ranges != null) {
      var diff = 0;
      for (final (start, old, size) in _ranges) {
        if (pos < start) break;
        if (pos <= start + old) {
          final result = StepMap(start, old, size).mapResult(pos, assoc);
          return MapResult(result.pos + diff, result.deleted);
        }
        diff += size - old;
      }
      return MapResult(pos + diff, false);
    }
    if (pos < from) return MapResult(pos, false);
    if (pos > from + oldSize) return MapResult(pos + newSize - oldSize, false);
    final side = oldSize == 0
        ? assoc
        : pos == from
        ? -1
        : pos == from + oldSize
        ? 1
        : assoc;
    return MapResult(
      from + (side < 0 ? 0 : newSize),
      pos != (assoc < 0 ? from : from + oldSize),
    );
  }

  StepMap invert() {
    if (_ranges == null) return StepMap(from, newSize, oldSize);
    var diff = 0;
    return StepMap.ranges(
      _ranges.map((r) {
        final result = (r.$1 + diff, r.$3, r.$2);
        diff += r.$3 - r.$2;
        return result;
      }).toList(),
    );
  }
}

class Mapping {
  Mapping([Iterable<StepMap> maps = const []]) : maps = List.unmodifiable(maps);
  final List<StepMap> maps;
  int map(int pos, [int assoc = 1]) {
    for (final m in maps) {
      pos = m.map(pos, assoc);
    }
    return pos;
  }

  MapResult mapResult(int pos, [int assoc = 1]) {
    var deleted = false;
    for (final m in maps) {
      final result = m.mapResult(pos, assoc);
      pos = result.pos;
      deleted |= result.deleted;
    }
    return MapResult(pos, deleted);
  }

  Mapping append(StepMap map) => Mapping([...maps, map]);
  Mapping invert() => Mapping(maps.reversed.map((m) => m.invert()));
}

/// Indices refer to the document immediately before and after this replacement.
class BlockRange {
  const BlockRange(this.from, this.oldTo, this.newTo);
  final int from;
  final int oldTo;
  final int newTo;
}

/// Child indices in the common parent, addressed by indices from the document.
class NestedRange {
  NestedRange(Iterable<int> path, this.from, this.oldTo, this.newTo)
    : path = List.unmodifiable(path);
  final List<int> path;
  final int from, oldTo, newTo;
}
