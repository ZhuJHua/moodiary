part of '../model.dart';

class SearchMatch {
  const SearchMatch(this.from, this.to);
  final int from, to;
  SearchMatch shift(int delta) => SearchMatch(from + delta, to + delta);
}

class SearchStatus {
  const SearchStatus({
    this.query = '',
    this.total = 0,
    this.current = 0,
    this.complete = true,
  });
  final String query;
  final int total, current;
  final bool complete;
}

/// Literal ProseMirror search over identity-cached textblocks. Each row can be
/// indexed independently, allowing hosts to prioritize visible rows and yield.
class SearchIndex {
  SearchIndex({this.query = '', this.caseSensitive = false});
  final String query;
  final bool caseSensitive;
  static final Expando<String> _text = Expando<String>();
  final Expando<List<SearchMatch>> _matches = Expando<List<SearchMatch>>();
  int scannedBlocks = 0;
  List<SearchMatch> matches(Node node) => _matches[node] ??= _scan(node);
  List<SearchMatch> _scan(Node node) {
    if (query.isEmpty) return const [];
    if (node.isTextblock) {
      scannedBlocks++;
      final text = _text[node] ??= node.content
          .map((n) => n.text ?? '\ufffc')
          .join();
      final haystack = caseSensitive ? text : text.toLowerCase(),
          needle = caseSensitive ? query : query.toLowerCase();
      final result = <SearchMatch>[];
      for (var at = 0; ;) {
        final found = haystack.indexOf(needle, at);
        if (found < 0) break;
        result.add(SearchMatch(found + 1, found + needle.length + 1));
        at = found + 1;
      }
      return List.unmodifiable(result);
    }
    if (node.isLeaf) return const [];
    var position = 1;
    final result = <SearchMatch>[];
    for (final child in node.content) {
      result.addAll(matches(child).map((m) => m.shift(position)));
      position += child.nodeSize;
    }
    return List.unmodifiable(result);
  }

  final Expando<List<SearchMatch>> _partial = Expando<List<SearchMatch>>();
  Iterable<SearchMatch> knownMatches(Node node) sync* {
    final cached = _matches[node] ?? _partial[node];
    if (cached != null) {
      yield* cached;
      return;
    }
    if (node.isTextblock || node.isLeaf) return;
    var position = 1;
    for (final child in node.content) {
      yield* knownMatches(child).map((m) => m.shift(position));
      position += child.nodeSize;
    }
  }

  /// Bounded scanning also handles a single multi-million-character paragraph.
  /// Hosts share the stopwatch across rows to yield to the event loop regularly.
  Future<void> prepare(
    Node node,
    Stopwatch budget, {
    bool Function()? cancelled,
    void Function()? onYield,
  }) async {
    if (_matches[node] != null || cancelled?.call() == true) return;
    if (query.isEmpty || node.isLeaf && !node.isTextblock) {
      _matches[node] = const [];
      return;
    }
    if (node.isTextblock) {
      scannedBlocks++;
      final text = _text[node] ??= node.content
          .map((n) => n.text ?? '\ufffc')
          .join();
      final haystack = caseSensitive ? text : text.toLowerCase(),
          needle = caseSensitive ? query : query.toLowerCase();
      final result = _partial[node] = <SearchMatch>[];
      for (var chunk = 0; chunk < haystack.length; chunk += 4096) {
        if (cancelled?.call() == true) return;
        final end = math.min(haystack.length, chunk + 4096),
            part = haystack.substring(
              chunk,
              math.min(haystack.length, end + needle.length - 1),
            );
        for (var at = 0; ;) {
          final hit = part.indexOf(needle, at);
          if (hit < 0 || chunk + hit >= end) break;
          result.add(
            SearchMatch(chunk + hit + 1, chunk + hit + needle.length + 1),
          );
          at = hit + 1;
        }
        if (budget.elapsedMicroseconds >= 1500) {
          onYield?.call();
          await Future<void>.delayed(Duration.zero);
          budget.reset();
        }
      }
      _matches[node] = List.unmodifiable(result);
      _partial[node] = null;
    } else {
      for (final child in node.content) {
        await prepare(child, budget, cancelled: cancelled, onYield: onYield);
        if (cancelled?.call() == true) return;
      }
      var position = 1;
      final result = <SearchMatch>[];
      for (final child in node.content) {
        result.addAll(
          (_matches[child] ?? const <SearchMatch>[]).map(
            (m) => m.shift(position),
          ),
        );
        position += child.nodeSize;
      }
      _matches[node] = List.unmodifiable(result);
    }
  }

  List<SearchMatch> rowMatches(DocumentRow row, {bool preparedOnly = false}) =>
      (preparedOnly ? knownMatches(row.node) : matches(row.node))
          .map((m) => m.shift(row.position))
          .toList();
  List<SearchMatch> findAll(Node doc) {
    final result = <SearchMatch>[];
    var end = 0;
    for (final row in doc.rows()) {
      for (final match in rowMatches(row)) {
        if (match.from >= end) {
          result.add(match);
          end = match.to;
        }
      }
    }
    return result;
  }

  SearchMatch? findNext(Node doc, int from, {int? to}) {
    if (query.isEmpty || doc.rowCount == 0) return null;
    for (
      var r = doc.rowIndexAt(from.clamp(0, doc.content.size));
      r < doc.rowCount;
      r++
    ) {
      final row = doc.rowAt(r);
      if (row.position > (to ?? doc.content.size)) break;
      for (final match in rowMatches(row)) {
        if (match.from >= from && match.to <= (to ?? doc.content.size)) {
          return match;
        }
      }
    }
    return null;
  }

  SearchMatch? findPrev(Node doc, int from, {int to = 0}) {
    if (query.isEmpty || doc.rowCount == 0) return null;
    for (var r = doc.rowIndexAt(from.clamp(0, doc.content.size)); r >= 0; r--) {
      final row = doc.rowAt(r);
      for (final match in rowMatches(row).reversed) {
        if (match.to <= from && match.from >= to) return match;
      }
    }
    return null;
  }

  Transaction start(EditorState state) {
    final hit =
        findNext(state.doc, state.selection.from) ?? findNext(state.doc, 0);
    return hit == null
        ? state.tr
        : state.tr.setSelection(TextSelection(hit.from, hit.to));
  }

  Transaction next(EditorState state, {bool backwards = false}) {
    final sel = state.selection, doc = state.doc;
    final hit = backwards
        ? (findPrev(doc, sel.from) ??
              findPrev(doc, doc.content.size, to: sel.to))
        : (findNext(doc, sel.to) ?? findNext(doc, 0, to: sel.from));
    return hit == null
        ? state.tr
        : state.tr.setSelection(TextSelection(hit.from, hit.to));
  }

  Transaction replaceCurrent(EditorState state, String replacement) {
    final sel = state.selection, doc = state.doc, tr = state.tr;
    final hit = findNext(doc, sel.from) ?? findNext(doc, 0, to: sel.from);
    if (hit == null) return tr;
    if (hit.from != sel.from || hit.to != sel.to) {
      return tr.setSelection(TextSelection(hit.from, hit.to));
    }
    final after = findNext(doc, hit.to) ?? findNext(doc, 0, to: hit.from);
    _replaceMatch(tr, hit, replacement);
    return tr
        .setSelection(
          after == null
              ? TextSelection(hit.from, tr.mapping.map(hit.to))
              : TextSelection(
                  tr.mapping.map(after.from, 1),
                  tr.mapping.map(after.to, -1),
                ),
        )
        .setMeta('closeHistory', true);
  }

  Transaction replaceAll(EditorState state, String replacement) {
    final tr = state.tr;
    for (final match in findAll(state.doc).reversed) {
      _replaceMatch(tr, match, replacement);
    }
    return tr.setMeta('closeHistory', true);
  }

  Future<Transaction> replaceAllAsync(
    EditorState state,
    String replacement,
  ) async {
    final tr = state.tr, watch = Stopwatch()..start();
    for (final match in findAll(state.doc).reversed) {
      _replaceMatch(tr, match, replacement);
      if (watch.elapsedMicroseconds >= 1500) {
        await Future<void>.delayed(Duration.zero);
        watch.reset();
      }
    }
    return tr.setMeta('closeHistory', true);
  }

  void _replaceMatch(Transaction tr, SearchMatch match, String replacement) {
    final original = tr.doc.slice(match.from, match.to).content;
    final marks = tr.doc.resolve(match.from).marks;
    var pending = Fragment.empty,
        pos = match.from,
        text = replacement,
        highestSeen = -1;
    final replacements = <(int, int, Fragment)>[];
    void add(String text) {
      if (text.isNotEmpty) {
        pending = pending.append(
          Fragment([tr.doc.schema.node('text', text: text, marks: marks)]),
        );
      }
    }

    while (text.isNotEmpty) {
      final part = RegExp(r'\$([$&\d+])').firstMatch(text);
      if (part == null) {
        add(text);
        break;
      }
      if (part.start > 0) {
        add(text.substring(0, part.start + (part[1] == '\$' ? 1 : 0)));
      }
      if (part[1] != '\$') {
        final group = part[1] == '&' ? 0 : int.tryParse(part[1]!);
        final copy = group != null && highestSeen >= group;
        highestSeen = group == null
            ? highestSeen
            : group == 0
            ? 1000
            : group;
        if (group == 0) {
          if (copy) {
            pending = pending.append(original);
          } else {
            if (pending.isNotEmpty || match.from > pos) {
              replacements.add((pos, match.from, pending));
            }
            pending = Fragment.empty;
            pos = match.to;
          }
        }
      }
      text = text.substring(part.end);
    }
    if (pending.isNotEmpty || pos < match.to) {
      replacements.add((pos, match.to, pending));
    }
    for (final range in replacements.reversed) {
      tr.replace(range.$1, range.$2, Slice(range.$3, 0, 0));
    }
  }
}
