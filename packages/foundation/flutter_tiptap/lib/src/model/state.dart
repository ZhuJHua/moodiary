part of '../model.dart';

/// Accumulates document steps and selection updates to apply to an editor state.
class Transaction {
  Transaction(EditorState state)
    : _documents = [state.doc],
      before = state.doc,
      doc = state.doc,
      selection = state.selection,
      storedMarks = state.storedMarks;
  _InputRuleUndo? _inputRuleUndo;
  History? _historyOverride;
  final List<Node> _documents;

  /// Immutable states at step boundaries, including before and final document.
  List<Node> get documents => List.unmodifiable(_documents);
  final Node before;
  Node doc;
  Selection selection;
  List<Mark>? storedMarks;
  final List<Step> _steps = [];
  final List<Step> _inverses = [];
  final List<BlockRange> _replacements = [];
  final List<NestedRange> _nestedReplacements = [];

  /// One range per step, addressed in that step's before/after documents.
  List<NestedRange> get nestedReplacements =>
      List.unmodifiable(_nestedReplacements);
  Transaction replace(int from, int to, [Slice? slice]) {
    final fitted = replaceStep(doc, from, to, slice ?? Slice.empty);
    return fitted == null ? this : step(fitted);
  }

  List<Step> get steps => List.unmodifiable(_steps);
  List<Step> get inverses => List.unmodifiable(_inverses.reversed);
  List<BlockRange> get replacements => List.unmodifiable(_replacements);
  BlockRange? get replacedBlocks => _replacedBlocks;
  BlockRange? _replacedBlocks;
  Mapping mapping = Mapping();
  final Map<String, Object?> metadata = {};
  bool selectionSet = false;
  bool get docChanged => _steps.isNotEmpty;
  bool get addToHistory => metadata['addToHistory'] != false;
  bool get composing => metadata['composition'] != null;
  Transaction step(Step step) {
    final result = step.apply(doc);
    final inverse = step._inverseFor(doc, result);
    final map = step.getMap();
    if (step is _DocumentStep || step is _RestoreBlocksStep) {
      final r = result.blocks;
      _nestedReplacements.add(NestedRange(const [], r.from, r.oldTo, r.newTo));
    } else {
      final a = doc.resolve(step.changedFrom.clamp(0, doc.content.size));
      final b = doc.resolve(step.changedTo.clamp(0, doc.content.size));
      final nextA = result.doc.resolve(
        map.map(a.pos, -1).clamp(0, result.doc.content.size),
      );
      final nextB = result.doc.resolve(
        map.map(b.pos, 1).clamp(0, result.doc.content.size),
      );
      var depth = math.min(a.sharedDepth(b.pos), nextA.sharedDepth(nextB.pos));
      while (depth > 0) {
        final samePath = List.generate(depth, (i) => i).every(
          (i) => a.index(i) == nextA.index(i) && a.index(i) == nextB.index(i),
        );
        if (samePath && a.node(depth).type == nextA.node(depth).type) break;
        depth--;
      }
      final nodeMarkup =
          step is _SetNodeStep || step is AttrStep && step.position >= 0;
      _nestedReplacements.add(
        NestedRange(
          List.generate(depth, (i) => a.index(i)),
          a.index(depth),
          nodeMarkup ? a.index(depth) + 1 : b.indexAfter(depth),
          nodeMarkup ? nextA.index(depth) + 1 : nextB.indexAfter(depth),
        ),
      );
    }
    _steps.add(step);
    _inverses.add(inverse);
    _replacements.add(result.blocks);
    doc = result.doc;
    _documents.add(doc);
    selection = selection.map(doc, Mapping([map]));
    mapping = mapping.append(map);
    final r = result.blocks, prev = _replacedBlocks;
    if (prev == null) {
      _replacedBlocks = r;
    } else {
      final delta = prev.newTo - prev.oldTo;
      _replacedBlocks = BlockRange(
        math.min(prev.from, r.from),
        math.max(prev.oldTo, r.oldTo - delta),
        math.max(r.newTo, prev.newTo + r.newTo - r.oldTo),
      );
    }
    return this;
  }

  Transaction setSelection(Selection value) {
    RangeError.checkValueInInterval(
      value.anchor,
      0,
      doc.content.size,
      'anchor',
    );
    RangeError.checkValueInInterval(value.head, 0, doc.content.size, 'head');
    selectionSet = true;
    selection = _normalizeTableSelection(doc, value);
    storedMarks = null;
    return this;
  }

  Transaction setStoredMarks(List<Mark>? marks) {
    storedMarks = marks == null ? null : List.unmodifiable(marks);
    return this;
  }

  Transaction setMeta(String key, Object? value) {
    metadata[key] = value;
    return this;
  }
}

class _Snapshot {
  const _Snapshot(this.doc, this.selection, this.storedMarks);
  final Node doc;
  final Selection selection;
  final List<Mark>? storedMarks;
}

class _HistoryEvent {
  const _HistoryEvent(
    this.before,
    this.after,
    this.time,
    this.from,
    this.to,
    this.composition,
    this.blocks,
    this.mapping, {
    this.nested,
  });
  final _Snapshot before;
  final _Snapshot after;
  final int time;
  final int from;
  final int to;
  final Object? composition;
  final BlockRange blocks;
  final Mapping mapping;
  final NestedRange? nested;
}

class History {
  History({this.depth = 100, this.groupDelay = 500})
    : _done = const [],
      _undone = const [];
  History._(this.depth, this.groupDelay, this._done, this._undone);
  final int depth;
  final int groupDelay;
  final List<_HistoryEvent> _done;
  final List<_HistoryEvent> _undone;
  bool get canUndo => _done.isNotEmpty;
  bool get canRedo => _undone.isNotEmpty;
}

class _InputRuleUndo {
  const _InputRuleUndo(
    this.typed,
    this.selection,
    this.blockIndex,
    this.mapping,
  );
  final Node typed;
  final Selection selection;
  final int blockIndex;
  final Mapping mapping;
}

/// An immutable snapshot of the document, selection, stored marks and undo history.
class EditorState {
  EditorState({
    required Node doc,
    Selection? selection,
    List<Mark>? storedMarks,
    History? history,
  }) : doc = fixTables(doc),
       selection = selection ?? _firstSelection(fixTables(doc)),
       storedMarks = storedMarks == null
           ? null
           : List.unmodifiable(storedMarks),
       history = history ?? History(),
       _inputRule = null;
  EditorState._(
    this.doc,
    this.selection,
    this.storedMarks,
    this.history,
    this._inputRule,
  );
  final Node doc;
  final Selection selection;
  final List<Mark>? storedMarks;
  final History history;
  final _InputRuleUndo? _inputRule;
  bool get canUndoInputRule => _inputRule != null;
  Transaction get tr => Transaction(this);
  _Snapshot get _snapshot => _Snapshot(doc, selection, storedMarks);
  static Selection _firstSelection(Node doc) {
    return Selection.near(doc, 0);
  }

  EditorState apply(Transaction transaction, {int? time}) {
    if (!identical(transaction.before, doc)) {
      throw StateError('Transaction belongs to a different document');
    }
    var h = transaction._historyOverride ?? history;
    final next = _Snapshot(
      transaction.doc,
      transaction.selection,
      transaction.storedMarks == null
          ? null
          : List.unmodifiable(transaction.storedMarks!),
    );
    if (transaction.docChanged &&
        !transaction.addToHistory &&
        transaction._historyOverride == null) {
      h = _rebaseHistory(h, transaction);
    }
    if (transaction.docChanged && transaction.addToHistory) {
      final now = time ?? DateTime.now().millisecondsSinceEpoch;
      final previous = h._done.isEmpty ? null : h._done.last;
      final maps = transaction.mapping.maps.where(
        (m) => m.oldSize != 0 || m.newSize != 0,
      );
      final from = maps.isEmpty ? selection.from : maps.first.from;
      final to = maps.isEmpty
          ? selection.to
          : maps.last.from + maps.last.newSize;
      final composition = transaction.metadata['composition'];
      final adjacent =
          previous != null && from <= previous.to && to >= previous.from;
      final group =
          previous != null &&
          transaction.metadata['closeHistory'] != true &&
          ((composition != null && composition == previous.composition) ||
              (now - previous.time < h.groupDelay && adjacent));
      final done = [...h._done];
      final before = group ? done.removeLast().before : _snapshot;
      final blocks = transaction.replacedBlocks!;
      final previousBlocks = group ? previous.blocks : null;
      final combined = previousBlocks == null
          ? blocks
          : BlockRange(
              math.min(previousBlocks.from, blocks.from),
              math.max(
                previousBlocks.oldTo,
                blocks.oldTo - (previousBlocks.newTo - previousBlocks.oldTo),
              ),
              math.max(
                blocks.newTo,
                previousBlocks.newTo + blocks.newTo - blocks.oldTo,
              ),
            );
      final mapping = group
          ? Mapping([...previous.mapping.maps, ...transaction.mapping.maps])
          : transaction.mapping;
      done.add(
        _HistoryEvent(
          before,
          next,
          now,
          from,
          to,
          composition,
          combined,
          mapping,
          nested: _combineNestedRanges([
            if (group && previous.nested != null) previous.nested!,
            ...transaction.nestedReplacements,
          ], invalid: group && previous.nested == null),
        ),
      );
      if (done.length > h.depth) done.removeRange(0, done.length - h.depth);
      h = History._(h.depth, h.groupDelay, List.unmodifiable(done), const []);
    }
    return EditorState._(
      next.doc,
      next.selection,
      next.storedMarks,
      h,
      transaction._inputRuleUndo ??
          (transaction.docChanged || transaction.selectionSet
              ? null
              : _inputRule),
    );
  }

  late final ToolbarState toolbar = _deriveToolbar();
  ToolbarState _deriveToolbar() {
    final resolved = doc.resolve(selection.from);
    String? type = resolved.parent.isTextblock ? resolved.parent.type : null;
    int? level = resolved.parent.type == 'heading'
        ? resolved.parent.attrs['level'] as int?
        : null;
    Set<String> active;
    if (selection.empty) {
      active = (storedMarks ?? resolved.marks).map((m) => m.type).toSet();
    } else {
      final first = doc.blocks.indexAt(selection.from),
          last = doc.blocks.indexAt(selection.to - 1);
      final summary = doc.blocks.summaryBetween(first, last + 1);
      type = summary.blockType;
      level = summary.headingLevel;
      var coverage = _MarkCoverage.zero;
      if (first < doc.childCount) {
        final block = doc.blocks[first],
            start = doc.blocks.positionAt(first) + 1;
        if (!block.isOpaque) {
          coverage += block._coverage(
            (selection.from - start).clamp(0, block.content.size),
            (selection.to - start).clamp(0, block.content.size),
          );
        }
      }
      if (last > first) {
        coverage += doc.blocks.summaryBetween(first + 1, last)._marks;
        final block = doc.blocks[last], start = doc.blocks.positionAt(last) + 1;
        if (!block.isOpaque) {
          coverage += block._coverage(
            0,
            (selection.to - start).clamp(0, block.content.size),
          );
        }
      }
      active = coverage.marks.keys.where((name) {
        final matched = coverage.marks[name] ?? 0;
        var excluded = 0;
        for (final entry in coverage.marks.entries) {
          final spec = doc.schema.marks[entry.key];
          if (entry.key != name &&
              (spec?.excludes.contains('*') == true ||
                  spec?.excludes.contains(name) == true)) {
            excluded += entry.value;
          }
        }
        return matched > 0 && matched + excluded >= coverage.length;
      }).toSet();
    }
    final end = doc.resolve(
      selection.empty ? selection.head : selection.to - 1,
    );
    return ToolbarState(
      Set.unmodifiable(active),
      type,
      level,
      history.canUndo,
      history.canRedo,
      selection is AllSelection
          ? SelectionKind.all
          : selection is NodeSelection
          ? SelectionKind.node
          : selection is CellSelection
          ? SelectionKind.cell
          : selection is GapSelection
          ? SelectionKind.gap
          : SelectionKind.text,
      cellPosition: tableContext(doc, selection.head)?.cellPosition,
      activeNodes: Set.unmodifiable(
        {
          for (var d = 1; d <= resolved.depth; d++) resolved.node(d).type,
        }.intersection({for (var d = 1; d <= end.depth; d++) end.node(d).type}),
      ),
      taskChecked: selection.empty
          ? [
              for (var d = resolved.depth; d > 0; d--)
                if (resolved.node(d).type == 'taskItem')
                  resolved.node(d).attrs['checked'] as bool,
            ].firstOrNull
          : null,
    );
  }
}

enum SelectionKind { text, node, all, cell, gap }

class ToolbarState {
  const ToolbarState(
    this.activeMarks,
    this.blockType,
    this.headingLevel,
    this.canUndo,
    this.canRedo,
    this.selectionKind, {
    this.activeNodes = const {},
    this.taskChecked,
    this.cellPosition,
  });
  final Set<String> activeMarks;
  final String? blockType;
  final int? headingLevel;
  final bool canUndo;
  final bool canRedo;
  final SelectionKind selectionKind;
  final Set<String> activeNodes;

  /// Checked state of the enclosing task at a collapsed selection.
  final bool? taskChecked;
  final int? cellPosition;
  bool get inTable => cellPosition != null;
}

NestedRange? _combineNestedRanges(
  Iterable<NestedRange> ranges, {
  bool invalid = false,
}) {
  if (invalid) return null;
  NestedRange? combined;
  for (final r in ranges) {
    final previous = combined;
    if (previous == null) {
      combined = r;
    } else {
      if (!_equal(previous.path, r.path)) return null;
      combined = NestedRange(
        r.path,
        math.min(previous.from, r.from),
        math.max(previous.oldTo, r.oldTo - previous.newTo + previous.oldTo),
        math.max(r.newTo, previous.newTo + r.newTo - r.oldTo),
      );
    }
  }
  return combined;
}
