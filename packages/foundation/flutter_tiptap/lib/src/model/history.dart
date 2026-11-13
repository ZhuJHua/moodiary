part of '../model.dart';

Step? _mapHistoryStep(Step step, Mapping mapping, Node source, Node target) {
  switch (step) {
    case ReplaceStep():
      final from = mapping.map(step.from, 1), to = mapping.map(step.to, -1);
      return ReplaceStep(math.min(from, to), math.max(from, to), step.slice);
    case AddMarkStep():
      return AddMarkStep(
        mapping.map(step.from, 1),
        mapping.map(step.to, -1),
        step.mark,
      );
    case RemoveMarkStep():
      return RemoveMarkStep(
        mapping.map(step.from, 1),
        mapping.map(step.to, -1),
        step.mark,
      );
    case AttrStep():
      if (step.position == -1) return step;
      final position = mapping.mapResult(step.position, 1);
      if (position.deleted || position.pos == target.content.size) return null;
      return AttrStep(position.pos, step.attr, step.value);
    case _SetNodeStep():
      final position = mapping.mapResult(step.position);
      if (position.deleted || position.pos >= target.content.size) return null;
      final original = source.nodeAt(step.position),
          mapped = target.nodeAt(position.pos);
      if (mapped == null) return null;
      return _SetNodeStep(
        position.pos,
        original != null && original.content.eq(step.node.content)
            ? step.node.copy(mapped.content)
            : step.node,
      );
    case ReplaceAroundStep():
      return ReplaceAroundStep(
        mapping.map(step.from, 1),
        mapping.map(step.to, -1),
        mapping.map(step.gapFrom, -1),
        mapping.map(step.gapTo, 1),
        step.slice,
        step.insert,
      );
    case _RestoreBlocksStep():
      final from = target.blocks.indexAt(
        mapping.map(source.blocks.positionAt(step.from), 1),
      );
      final to = target.blocks.indexAt(
        mapping.map(source.blocks.positionAt(step.to), -1),
      );
      final nodes = <Node>[];
      for (var i = 0; i < step.nodes.length; i++) {
        final node = step.nodes[i];
        final original = step.from + i < source.childCount
            ? source.blocks[step.from + i]
            : null;
        final mapped = from + i < target.childCount
            ? target.blocks[from + i]
            : null;
        final markupOnly =
            original != null &&
            mapped != null &&
            original.isTextblock &&
            node.isTextblock &&
            original.content.eq(node.content);
        nodes.add(markupOnly ? node.copy(mapped.content) : node);
      }
      return _RestoreBlocksStep(
        math.min(from, to),
        math.max(from, to),
        nodes,
        step.mapping,
      );
    default:
      throw UnsupportedError(
        'Cannot rebase ${step.runtimeType} through history',
      );
  }
}

(_HistoryEvent, List<Step>) _rebaseEvent(
  _HistoryEvent event,
  List<Step> patches, {
  required bool backward,
}) {
  final sourceSnapshot = backward ? event.after : event.before;
  final targetSnapshot = backward ? event.before : event.after;
  var source = sourceSnapshot.doc, target = targetSnapshot.doc;
  var translation = backward ? event.mapping.invert() : event.mapping;
  var sourceMapping = Mapping(), targetMapping = Mapping();
  final mappedPatches = <Step>[];
  for (final patch in patches) {
    final mapped = _mapHistoryStep(patch, translation, source, target);
    final sourceResult = patch.apply(source);
    final targetResult = mapped?.apply(target);
    final sourceMap = patch.getMap(),
        targetMap = mapped?.getMap() ?? StepMap.empty;
    source = sourceResult.doc;
    if (targetResult != null) {
      target = targetResult.doc;
      mappedPatches.add(mapped!);
    }
    sourceMapping = sourceMapping.append(sourceMap);
    targetMapping = targetMapping.append(targetMap);
    translation = Mapping([sourceMap.invert(), ...translation.maps, targetMap]);
  }
  final newSource = _Snapshot(
    source,
    sourceSnapshot.selection.map(source, sourceMapping),
    sourceSnapshot.storedMarks,
  );
  final newTarget = _Snapshot(
    target,
    targetSnapshot.selection.map(target, targetMapping),
    targetSnapshot.storedMarks,
  );
  final before = backward ? newTarget : newSource,
      after = backward ? newSource : newTarget;
  final beforeMap = backward ? targetMapping : sourceMapping,
      afterMap = backward ? sourceMapping : targetMapping;
  final range = event.blocks;
  final from = before.doc.blocks.indexAt(
    beforeMap.map(event.before.doc.blocks.positionAt(range.from), 1),
  );
  final oldTo = before.doc.blocks.indexAt(
    beforeMap.map(event.before.doc.blocks.positionAt(range.oldTo), -1),
  );
  final newTo = after.doc.blocks.indexAt(
    afterMap.map(event.after.doc.blocks.positionAt(range.newTo), -1),
  );
  return (
    _HistoryEvent(
      before,
      after,
      event.time,
      afterMap.map(event.from),
      afterMap.map(event.to),
      event.composition,
      BlockRange(from, math.max(from, oldTo), math.max(from, newTo)),
      backward ? translation.invert() : translation,
      blockMove: event.blockMove == null
          ? null
          : (
              before: beforeMap.map(event.blockMove!.before),
              after: afterMap.map(event.blockMove!.after),
            ),
    ),
    mappedPatches,
  );
}

History _rebaseHistory(History history, Transaction transaction) {
  final done = <_HistoryEvent>[], undone = <_HistoryEvent>[];
  var patches = transaction.steps;
  for (final event in history._done.reversed) {
    final (rebased, mapped) = _rebaseEvent(event, patches, backward: true);
    done.add(rebased);
    patches = mapped;
  }
  patches = transaction.steps;
  for (final event in history._undone.reversed) {
    final (rebased, mapped) = _rebaseEvent(event, patches, backward: false);
    undone.add(rebased);
    patches = mapped;
  }
  return History._(
    history.depth,
    history.groupDelay,
    List.unmodifiable(done.reversed),
    List.unmodifiable(undone.reversed),
  );
}
