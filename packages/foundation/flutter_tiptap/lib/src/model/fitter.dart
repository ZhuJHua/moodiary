part of '../model.dart';

/// Fits a slice using ProseMirror's frontier algorithm. Returns null for no-op
/// edits or slices that cannot be fitted into the schema.
Step? replaceStep(Node doc, int from, int to, [Slice? slice]) {
  slice ??= Slice.empty;
  if (from == to && slice.size == 0) return null;
  final a = doc.resolve(from), b = doc.resolve(to);
  if (slice.openStart == 0 &&
      slice.openEnd == 0 &&
      a.start() == b.start() &&
      a.parent.canReplace(a.index(), b.index(), slice.content)) {
    return ReplaceStep(from, to, slice);
  }
  return _Fitter(a, b, slice).fit();
}

class _Frontier {
  _Frontier(this.type, this.match);
  final String type;
  ContentMatch match;
}

class _Fittable {
  const _Fittable(
    this.sliceDepth,
    this.frontierDepth,
    this.parent, {
    this.inject,
    this.wrap,
  });
  final int sliceDepth, frontierDepth;
  final Node? parent;
  final Fragment? inject;
  final List<String>? wrap;
}

class _Fitter {
  _Fitter(this.from, this.to, this.unplaced) {
    for (var i = 0; i <= from.depth; i++) {
      final node = from.node(i);
      frontier.add(
        _Frontier(node.type, node.contentMatchAt(from.indexAfter(i))),
      );
    }
    for (var i = from.depth; i > 0; i--) {
      placed = Fragment([from.node(i).copy(placed)]);
    }
  }
  final ResolvedPos from, to;
  final List<_Frontier> frontier = [];
  Slice unplaced;
  Fragment placed = Fragment.empty;
  Schema get schema => from.doc.schema;
  int get depth => frontier.length - 1;
  Step? fit() {
    while (unplaced.size != 0) {
      final found = findFittable();
      if (found != null) {
        placeNodes(found);
      } else if (!openMore()) {
        dropNode();
      }
    }
    final move = mustMoveInline();
    final placedSize = placed.size - depth - from.depth;
    final closed = close(move < 0 ? to : from.doc.resolve(move));
    if (closed == null) return null;
    var content = placed, openStart = from.depth, openEnd = closed.depth;
    while (openStart > 0 && openEnd > 0 && content.length == 1) {
      content = content.first.content;
      openStart--;
      openEnd--;
    }
    final slice = Slice(content, openStart, openEnd);
    if (move >= 0) {
      return ReplaceAroundStep(
        from.pos,
        move,
        to.pos,
        to.end(),
        slice,
        placedSize,
      );
    }
    return slice.size != 0 || from.pos != to.pos
        ? ReplaceStep(from.pos, closed.pos, slice)
        : null;
  }

  _Fittable? findFittable() {
    for (var pass = 1; pass <= 2; pass++) {
      for (var sd = unplaced.openStart; sd >= 0; sd--) {
        final parent = sd > 0
            ? _contentAt(unplaced.content, sd - 1).first
            : null;
        final fragment = parent?.content ?? unplaced.content;
        final first = fragment.isEmpty ? null : fragment.first;
        for (var fd = depth; fd >= 0; fd--) {
          final top = frontier[fd];
          Fragment? inject;
          if (pass == 1 &&
              (first != null
                  ? top.match.matchType(first.type) != null ||
                        (inject = top.match.fillBefore(Fragment([first]))) !=
                            null
                  : parent != null &&
                        schema.compatibleContent(top.type, parent.type))) {
            return _Fittable(sd, fd, parent, inject: inject);
          }
          if (pass == 2 && first != null) {
            final wrap = top.match.findWrapping(first.type);
            if (wrap != null) return _Fittable(sd, fd, parent, wrap: wrap);
          }
          if (parent != null && top.match.matchType(parent.type) != null) break;
        }
      }
    }
    return null;
  }

  bool openMore() {
    int maxOpen(Fragment content, bool end) {
      var count = 0;
      while (content.isNotEmpty &&
          !(end ? content.last : content.first).isAtom) {
        content = (end ? content.last : content.first).content;
        count++;
      }
      return count;
    }

    if (maxOpen(unplaced.content, false) <= unplaced.openStart) return false;
    var end = unplaced.openEnd;
    if (unplaced.size > 1 && maxOpen(unplaced.content, true) > end) end++;
    unplaced = Slice(unplaced.content, unplaced.openStart + 1, end);
    return true;
  }

  void dropNode() {
    final content = unplaced.content, start = unplaced.openStart;
    final inner = _contentAt(content, start);
    if (inner.length <= 1 && start > 0) {
      unplaced = Slice(
        _dropFromFragment(content, start - 1, 1),
        start - 1,
        content.size - start <= start + inner.size
            ? start - 1
            : unplaced.openEnd,
      );
    } else {
      unplaced = Slice(
        _dropFromFragment(content, start, 1),
        start,
        unplaced.openEnd,
      );
    }
  }

  void placeNodes(_Fittable fit) {
    while (depth > fit.frontierDepth) {
      closeFrontier();
    }
    for (final type in fit.wrap ?? const <String>[]) {
      openFrontier(type);
    }
    final slice = unplaced, fragment = fit.parent?.content ?? slice.content;
    final openStart = slice.openStart - fit.sliceDepth;
    var taken = 0, match = frontier[fit.frontierDepth].match;
    var add = fit.inject ?? Fragment.empty;
    match = match.matchFragment(add)!;
    var openEnd =
        fragment.size + fit.sliceDepth - (slice.content.size - slice.openEnd);
    while (taken < fragment.length) {
      var next = fragment[taken];
      final matches = match.matchType(next.type);
      if (matches == null) break;
      taken++;
      if (taken > 1 || openStart == 0 || next.content.isNotEmpty) {
        match = matches;
        if (schema.nodes[frontier[fit.frontierDepth].type]?.code == true) {
          next = next.withMarks(const []);
        }
        add = add.append(
          Fragment([
            _closeStart(
              next,
              taken == 1 ? openStart : 0,
              taken == fragment.length ? openEnd : -1,
            ),
          ]),
        );
      }
    }
    final toEnd = taken == fragment.length;
    if (!toEnd) openEnd = -1;
    placed = _addToFragment(placed, fit.frontierDepth, add);
    frontier[fit.frontierDepth].match = match;
    if (toEnd &&
        openEnd < 0 &&
        fit.parent != null &&
        fit.parent!.type == frontier.last.type &&
        depth > 0) {
      closeFrontier();
    }
    var cur = fragment;
    for (var i = 0; i < openEnd; i++) {
      final node = cur.last;
      frontier.add(_Frontier(node.type, node.contentMatchAt(node.childCount)));
      cur = node.content;
    }
    unplaced = !toEnd
        ? Slice(
            _dropFromFragment(slice.content, fit.sliceDepth, taken),
            slice.openStart,
            slice.openEnd,
          )
        : fit.sliceDepth == 0
        ? Slice.empty
        : Slice(
            _dropFromFragment(slice.content, fit.sliceDepth - 1, 1),
            fit.sliceDepth - 1,
            openEnd < 0 ? slice.openEnd : fit.sliceDepth - 1,
          );
  }

  int mustMoveInline() {
    if (!to.parent.isTextblock ||
        schema.nodes[frontier.last.type]?.textblock != true ||
        _afterFits(to, to.depth, frontier.last, false) == null ||
        (to.depth == depth && findCloseLevel(to)?.$1 == depth)) {
      return -1;
    }
    var d = to.depth, after = to.after();
    while (d > 1 && after == to.end(--d)) {
      after++;
    }
    return after;
  }

  (int, Fragment, ResolvedPos)? findCloseLevel(ResolvedPos target) {
    scan:
    for (var i = math.min(depth, target.depth); i >= 0; i--) {
      final drop =
          i < target.depth &&
          target.end(i + 1) == target.pos + target.depth - i - 1;
      final fit = _afterFits(target, i, frontier[i], drop);
      if (fit == null) continue;
      for (var d = i - 1; d >= 0; d--) {
        final match = _afterFits(target, d, frontier[d], true);
        if (match == null || match.isNotEmpty) continue scan;
      }
      return (i, fit, drop ? target.doc.resolve(target.after(i + 1)) : target);
    }
    return null;
  }

  ResolvedPos? close(ResolvedPos target) {
    final level = findCloseLevel(target);
    if (level == null) return null;
    while (depth > level.$1) {
      closeFrontier();
    }
    placed = _addToFragment(placed, level.$1, level.$2);
    target = level.$3;
    for (var d = level.$1 + 1; d <= target.depth; d++) {
      final node = target.node(d);
      openFrontier(
        node.type,
        node.attrs,
        schema
            .contentMatch(node.type)
            .fillBefore(node.content, toEnd: true, start: target.index(d))!,
        true,
      );
    }
    return target;
  }

  void openFrontier(
    String type, [
    Map<String, Object?>? attrs,
    Fragment? content,
    bool closing = false,
  ]) {
    // During close(), leading fillers have already been placed. The old
    // frontier is discarded after copying the target's open spine.
    if (!closing) frontier.last.match = frontier.last.match.matchType(type)!;
    placed = _addToFragment(
      placed,
      depth,
      Fragment([
        schema.node(type, attrs: attrs, content: content ?? Fragment.empty),
      ]),
    );
    frontier.add(_Frontier(type, schema.contentMatch(type)));
  }

  void closeFrontier() {
    final open = frontier.removeLast();
    final add = open.match.fillBefore(Fragment.empty, toEnd: true)!;
    if (add.isNotEmpty) placed = _addToFragment(placed, frontier.length, add);
  }

  Fragment? _afterFits(ResolvedPos target, int d, _Frontier top, bool open) {
    final node = target.node(d),
        index = open ? target.indexAfter(d) : target.index(d);
    if (index == node.childCount &&
        !schema.compatibleContent(top.type, node.type)) {
      return null;
    }
    if (schema.nodes[top.type]?.code == true &&
        node.content.skip(index).any((n) => n.marks.isNotEmpty)) {
      return null;
    }
    return top.match.fillBefore(node.content, toEnd: true, start: index);
  }
}

Fragment _contentAt(Fragment fragment, int depth) {
  for (var i = 0; i < depth; i++) {
    fragment = fragment.first.content;
  }
  return fragment;
}

Fragment _dropFromFragment(Fragment fragment, int depth, int count) =>
    depth == 0
    ? fragment.cutByIndex(count, fragment.length)
    : fragment.replaceChild(
        0,
        fragment.first.copy(
          _dropFromFragment(fragment.first.content, depth - 1, count),
        ),
      );
Fragment _addToFragment(Fragment fragment, int depth, Fragment content) =>
    depth == 0
    ? fragment.append(content)
    : fragment.replaceChild(
        fragment.length - 1,
        fragment.last.copy(
          _addToFragment(fragment.last.content, depth - 1, content),
        ),
      );
Node _closeStart(Node node, int openStart, int openEnd) {
  if (openStart <= 0) return node;
  var fragment = node.content;
  if (openStart > 1) {
    fragment = fragment.replaceChild(
      0,
      _closeStart(
        fragment.first,
        openStart - 1,
        fragment.length == 1 ? openEnd - 1 : 0,
      ),
    );
  }
  fragment = node.schema
      .contentMatch(node.type)
      .fillBefore(fragment)!
      .append(fragment);
  if (openEnd <= 0) {
    fragment = fragment.append(
      node.schema
          .contentMatch(node.type)
          .matchFragment(fragment)!
          .fillBefore(Fragment.empty, toEnd: true)!,
    );
  }
  return node.copy(fragment);
}
