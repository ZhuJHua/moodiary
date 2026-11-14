part of '../model.dart';

class StepResult {
  const StepResult(this.doc, this.blocks);
  final Node doc;
  final BlockRange blocks;
}

abstract class Step {
  const Step();
  StepResult apply(Node doc);
  Step invert(Node doc) => _inverseFor(doc, apply(doc));
  Step _inverseFor(Node doc, StepResult result) {
    final r = result.blocks;
    return _RestoreBlocksStep(
      r.from,
      r.newTo,
      doc.blocks.slice(r.from, r.oldTo),
      getMap().invert(),
    );
  }

  StepMap getMap();
  int get changedFrom => getMap().from;
  int get changedTo => changedFrom + getMap().oldSize;
}

class _RestoreBlocksStep extends Step {
  _RestoreBlocksStep(this.from, this.to, Iterable<Node> nodes, this.mapping)
    : nodes = BlockTree(nodes);
  final int from;
  final int to;
  final BlockTree nodes;
  final StepMap mapping;
  @override
  StepResult apply(Node doc) => StepResult(
    doc.replaceBlocks(from, to, nodes),
    BlockRange(from, to, from + nodes.length),
  );
  @override
  StepMap getMap() => mapping;
}

class ReplaceStep extends Step {
  const ReplaceStep(this.from, this.to, this.slice);
  final int from;
  final int to;
  final Slice slice;
  @override
  StepMap getMap() => StepMap(from, to - from, slice.size);
  @override
  StepResult apply(Node doc) {
    RangeError.checkValueInInterval(to, from, doc.content.size, 'to');
    final next = doc.replace(from, to, slice);
    final first = doc.content.indexAt(from);
    final oldTo = to == from
        ? (doc.resolve(from).depth > 0 ? first + 1 : first)
        : doc.content.indexAt(to) + (doc.resolve(to).depth > 0 ? 1 : 0);
    final last = next.content.indexAt(
      (from + slice.size).clamp(0, next.content.size),
    );
    final newTo =
        last +
        (next.resolve((from + slice.size).clamp(0, next.content.size)).depth > 0
            ? 1
            : 0);
    return StepResult(next, BlockRange(first, oldTo, newTo));
  }
}

abstract class _MarkStep extends Step {
  const _MarkStep(this.from, this.to, this.mark);
  final int from;
  final int to;
  final Mark mark;
  List<Mark> transform(Node node);
  @override
  int get changedFrom => from;
  @override
  int get changedTo => to;
  @override
  StepMap getMap() => StepMap.empty;
  @override
  StepResult apply(Node doc) {
    RangeError.checkValueInInterval(to, from, doc.content.size, 'to');
    Node visit(Node node, int start) {
      if (node.isOpaque || node.schema.nodes[node.type]?.code == true) {
        return node;
      }
      final a = (from - start).clamp(0, node.content.size);
      final b = (to - start).clamp(a, node.content.size);
      if (a == b) return node;
      if (node.isTextblock) {
        return node.copy(
          node.content
              .cut(0, a)
              .append(
                Fragment(
                  node.content.cut(a, b).map((n) => n.withMarks(transform(n))),
                ),
              )
              .append(node.content.cut(b)),
        );
      }
      final first = node.content.indexAt(a), last = node.content.indexAt(b - 1);
      var fragment = node.content;
      for (var i = first; i <= last; i++) {
        fragment = fragment.replaceChild(
          i,
          visit(node.child(i), start + node.content.positionAt(i) + 1),
        );
      }
      return node.copy(fragment);
    }

    final first = doc.content.indexAt(from);
    final end = to == from ? first : doc.content.indexAt(to - 1) + 1;
    return StepResult(visit(doc, 0), BlockRange(first, end, end));
  }
}

class AddMarkStep extends _MarkStep {
  const AddMarkStep(super.from, super.to, super.mark);
  @override
  List<Mark> transform(Node node) => node.schema.addMark(node.marks, mark);
}

class RemoveMarkStep extends _MarkStep {
  const RemoveMarkStep(super.from, super.to, super.mark);
  @override
  List<Mark> transform(Node node) =>
      node.marks.where((m) => m != mark).toList();
}

class AttrStep extends Step {
  const AttrStep(this.position, this.attr, this.value);
  final int position;
  final String attr;
  final Object? value;
  @override
  int get changedFrom => math.max(0, position);
  @override
  int get changedTo => changedFrom;
  @override
  StepMap getMap() => StepMap.empty;
  @override
  StepResult apply(Node doc) {
    if (position == -1) {
      return StepResult(
        doc.withAttrs({...doc.attrs, attr: value}),
        const BlockRange(0, 0, 0),
      );
    }
    final resolved = doc.resolve(position);
    final node = resolved.nodeAfter;
    if (node == null || resolved.textOffset != 0 || node.isOpaque) {
      throw ArgumentError('Expected editable node boundary');
    }
    Node visit(int depth) {
      final parent = resolved.node(depth), index = resolved.index(depth);
      return parent.copy(
        parent.content.replaceChild(
          index,
          depth == resolved.depth
              ? node.withAttrs({...node.attrs, attr: value})
              : visit(depth + 1),
        ),
      );
    }

    return StepResult(
      visit(0),
      BlockRange(
        resolved.blockIndex,
        resolved.blockIndex + 1,
        resolved.blockIndex + 1,
      ),
    );
  }

  @override
  Step _inverseFor(Node doc, StepResult result) {
    if (position == -1) return _DocumentStep(doc);
    final i = doc.blocks.indexAt(position);
    return _RestoreBlocksStep(i, i + 1, [doc.blocks[i]], StepMap.empty);
  }
}

/// Replaces the outer range while preserving a gap and inserting it into a slice.
class ReplaceAroundStep extends Step {
  const ReplaceAroundStep(
    this.from,
    this.to,
    this.gapFrom,
    this.gapTo,
    this.slice,
    this.insert,
  );
  final int from, to, gapFrom, gapTo, insert;
  final Slice slice;
  @override
  StepMap getMap() => StepMap.ranges([
    (from, gapFrom - from, insert),
    (gapTo, to - gapTo, slice.size - insert),
  ]);
  @override
  StepResult apply(Node doc) {
    final gap = doc.slice(gapFrom, gapTo);
    if (gap.openStart != 0 || gap.openEnd != 0) {
      throw ArgumentError('Gap is not flat');
    }
    final content = _insertInto(
      slice.content,
      insert + slice.openStart,
      gap.content,
    );
    if (content == null) throw ArgumentError('Gap does not fit slice');
    return ReplaceStep(
      from,
      to,
      Slice(content, slice.openStart, slice.openEnd),
    ).apply(doc);
  }
}
