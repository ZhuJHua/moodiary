part of '../model.dart';

Node _closeNode(Node node, Fragment content) {
  if (!node.validContent(content)) {
    throw ArgumentError('Invalid content for ${node.type}');
  }
  return node.copy(content);
}

Node _joinable(ResolvedPos a, ResolvedPos b, int depth) {
  final node = a.node(depth);
  if (!node.schema.compatibleContent(node.type, b.node(depth).type)) {
    throw ArgumentError('Cannot join ${b.node(depth).type} onto ${node.type}');
  }
  return node;
}

Fragment _addRange(ResolvedPos? start, ResolvedPos? end, int depth) {
  final node = (end ?? start)!.node(depth);
  var from = 0;
  final to = end?.index(depth) ?? node.childCount;
  var before = Fragment.empty, after = Fragment.empty;
  if (start != null) {
    from = start.index(depth);
    if (start.depth > depth) {
      from++;
    } else if (start.textOffset > 0) {
      before = Fragment([start.nodeAfter!]);
      from++;
    }
  }
  if (end != null && end.depth == depth && end.textOffset > 0) {
    after = Fragment([end.nodeBefore!]);
  }
  return before.append(node.content.cutByIndex(from, to)).append(after);
}

Fragment _replaceTwoWay(ResolvedPos from, ResolvedPos to, int depth) {
  var content = _addRange(null, from, depth);
  if (from.depth > depth) {
    final type = _joinable(from, to, depth + 1);
    content = content.append(
      Fragment([_closeNode(type, _replaceTwoWay(from, to, depth + 1))]),
    );
  }
  return content.append(_addRange(to, null, depth));
}

Fragment _replaceThreeWay(
  ResolvedPos from,
  ResolvedPos start,
  ResolvedPos end,
  ResolvedPos to,
  int depth,
) {
  final openStart = from.depth > depth
      ? _joinable(from, start, depth + 1)
      : null;
  final openEnd = to.depth > depth ? _joinable(end, to, depth + 1) : null;
  var content = _addRange(null, from, depth);
  if (openStart != null &&
      openEnd != null &&
      start.index(depth) == end.index(depth)) {
    if (!openStart.schema.compatibleContent(openStart.type, openEnd.type)) {
      throw ArgumentError('Incompatible join');
    }
    content = content.append(
      Fragment([
        _closeNode(
          openStart,
          _replaceThreeWay(from, start, end, to, depth + 1),
        ),
      ]),
    );
  } else {
    if (openStart != null) {
      content = content.append(
        Fragment([
          _closeNode(openStart, _replaceTwoWay(from, start, depth + 1)),
        ]),
      );
    }
    content = content.append(_addRange(start, end, depth));
    if (openEnd != null) {
      content = content.append(
        Fragment([_closeNode(openEnd, _replaceTwoWay(end, to, depth + 1))]),
      );
    }
  }
  return content.append(_addRange(to, null, depth));
}

Node _replace(ResolvedPos from, ResolvedPos to, Slice slice) {
  if (slice.openStart > from.depth ||
      from.depth - slice.openStart != to.depth - slice.openEnd) {
    throw ArgumentError('Inconsistent open slice depths');
  }
  Node outer(int depth) {
    final index = from.index(depth), node = from.node(depth);
    if (index == to.index(depth) && depth < from.depth - slice.openStart) {
      return node.copy(node.content.replaceChild(index, outer(depth + 1)));
    }
    if (slice.content.isEmpty) {
      return _closeNode(node, _replaceTwoWay(from, to, depth));
    }
    if (slice.openStart == 0 &&
        slice.openEnd == 0 &&
        from.depth == depth &&
        to.depth == depth) {
      return _closeNode(
        node,
        node.content
            .cut(0, from.parentOffset)
            .append(slice.content)
            .append(node.content.cut(to.parentOffset)),
      );
    }
    final extra = from.depth - slice.openStart;
    var prepared = from.node(extra).copy(slice.content);
    for (var i = extra - 1; i >= 0; i--) {
      prepared = from.node(i).copy(Fragment([prepared]));
    }
    final start = prepared.resolve(slice.openStart + extra);
    final end = prepared.resolve(prepared.content.size - slice.openEnd - extra);
    return _closeNode(node, _replaceThreeWay(from, start, end, to, depth));
  }

  return outer(0);
}

Fragment? _insertInto(
  Fragment content,
  int dist,
  Fragment insert, [
  Node? parent,
]) {
  final index = content.indexAt(dist), offset = content.positionAt(index);
  if (offset == dist || content[index].isText) {
    if (parent != null && !parent.canReplace(index, index, insert)) return null;
    return content.cut(0, dist).append(insert).append(content.cut(dist));
  }
  final child = content[index];
  final inner = _insertInto(child.content, dist - offset - 1, insert, child);
  return inner == null ? null : content.replaceChild(index, child.copy(inner));
}
