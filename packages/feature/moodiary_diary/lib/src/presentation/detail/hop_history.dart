/// 页内双链跳转历史（浏览器语义）。[cursor] 指向当前条目；前向 push 截断前进分支，
/// 超 [max] 丢最旧。历史里的日记可能已被删除（回收 / 同步硬删），由调用方在走动时
/// 经 [dropNext] 剔除。
class HopEntry {
  final String diaryId;

  /// 离开该篇时回填，回退时恢复。
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

  /// 历史起点（再退一步就该真正退出页面）。
  bool get atRoot => _cursor <= 0;

  HopEntry? get current =>
      _cursor >= 0 && _cursor < _entries.length ? _entries[_cursor] : null;

  /// 重置为单条（打开页面 / 外部导航接管）。
  void reset(String diaryId) {
    _entries
      ..clear()
      ..add(HopEntry(diaryId));
    _cursor = 0;
  }

  /// 前向跳转：截断前进分支后追加；超上限丢最旧。
  void push(String diaryId) {
    if (_entries.isNotEmpty) {
      _entries.removeRange(_cursor + 1, _entries.length);
    }
    _entries.add(HopEntry(diaryId));
    if (_entries.length > max) _entries.removeAt(0);
    _cursor = _entries.length - 1;
  }

  /// [delta] 方向的下一条；越界返回 null。
  HopEntry? peek(int delta) {
    final next = _cursor + delta;
    if (next < 0 || next >= _entries.length) return null;
    return _entries[next];
  }

  /// 走到 [delta] 方向的下一条（调用方已确认可走）。
  void move(int delta) => _cursor += delta;

  /// 剔除 [delta] 方向的下一条（目标已不存在）；游标随之校正。
  void dropNext(int delta) {
    final next = _cursor + delta;
    _entries.removeAt(next);
    if (next < _cursor) _cursor--;
  }
}
