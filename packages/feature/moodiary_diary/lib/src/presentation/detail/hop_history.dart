class HopEntry {
  final String diaryId;

  double scrollY = 0;

  HopEntry(this.diaryId);
}

class HopHistory {
  HopHistory({this.max = 50});

  final int max;
  final List<HopEntry> _entries = [];
  int _cursor = 0;

  bool get isEmpty => _entries.isEmpty;
  int get length => _entries.length;
  int get cursor => _cursor;

  bool get atRoot => _cursor <= 0;

  HopEntry? get current =>
      _cursor >= 0 && _cursor < _entries.length ? _entries[_cursor] : null;

  void reset(String diaryId) {
    _entries
      ..clear()
      ..add(HopEntry(diaryId));
    _cursor = 0;
  }

  void push(String diaryId) {
    if (_entries.isNotEmpty) {
      _entries.removeRange(_cursor + 1, _entries.length);
    }
    _entries.add(HopEntry(diaryId));
    if (_entries.length > max) _entries.removeAt(0);
    _cursor = _entries.length - 1;
  }

  HopEntry? peek(int delta) {
    final next = _cursor + delta;
    if (next < 0 || next >= _entries.length) return null;
    return _entries[next];
  }

  void move(int delta) => _cursor += delta;

  void dropNext(int delta) {
    final next = _cursor + delta;
    _entries.removeAt(next);
    if (next < _cursor) _cursor--;
  }
}
