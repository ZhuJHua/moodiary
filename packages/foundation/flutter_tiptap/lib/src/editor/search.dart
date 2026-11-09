part of '../editor.dart';

extension _SearchController on TiptapController {
  void _refreshSearch() {
    if (_searchIndex.query.isEmpty) return;
    if (!identical(_searchDoc, state.doc)) {
      _startSearchScan();
    } else {
      _publishSearch(_searchStatus.value.complete);
    }
  }

  void _publishSearch(bool complete) {
    final selection = state.selection;
    var low = 0, high = _searchMatches.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (_searchMatches[mid].from < selection.from) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    final current =
        low < _searchMatches.length &&
            _searchMatches[low].from == selection.from &&
            _searchMatches[low].to == selection.to
        ? low + 1
        : 0;
    _searchStatus.value = m.SearchStatus(
      query: _searchIndex.query,
      total: _searchMatches.length,
      current: current,
      complete: complete,
    );
  }

  void _startSearchScan() {
    final generation = ++_searchGeneration,
        doc = state.doc,
        index = _searchIndex;
    _searchDoc = doc;
    _searchMatches = [];
    _publishSearch(false);
    final done = Completer<void>();
    _searchDone = done.future;
    unawaited(() async {
      var end = 0;
      final watch = Stopwatch()..start();
      bool cancelled() => _disposed || generation != _searchGeneration;
      void progress() {
        if (!cancelled()) {
          _publishSearch(false);
          _searchNotify();
        }
      }

      for (
        var row = _searchVisible.$1;
        row < math.min(doc.rowCount, _searchVisible.$2);
        row++
      ) {
        await index.prepare(
          doc.rowAt(row).node,
          watch,
          cancelled: cancelled,
          onYield: progress,
        );
        if (cancelled()) break;
      }
      for (var row = 0; row < doc.rowCount; row++) {
        if (_disposed || generation != _searchGeneration) break;
        final value = doc.rowAt(row);
        await index.prepare(
          value.node,
          watch,
          cancelled: cancelled,
          onYield: progress,
        );
        if (cancelled()) break;
        for (final hit in index.rowMatches(value, preparedOnly: true)) {
          if (hit.from >= end) {
            _searchMatches.add(hit);
            end = hit.to;
          }
        }
        if (watch.elapsedMicroseconds >= 1500) {
          _publishSearch(false);
          _searchNotify();
          await Future<void>.delayed(Duration.zero);
          watch.reset();
        }
      }
      if (!_disposed && generation == _searchGeneration) {
        _publishSearch(true);
        _searchNotify();
      }
      done.complete();
    }());
  }
}
