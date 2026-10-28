import 'dart:async';

import 'package:injectable/injectable.dart';

@singleton
class OpenDiaryRegistry {
  final Map<String, int> _open = <String, int>{};
  final StreamController<String> _closed = StreamController<String>.broadcast();

  Stream<String> get closed => _closed.stream;

  void open(String id) {
    if (id.isEmpty) return;
    _open[id] = (_open[id] ?? 0) + 1;
  }

  void close(String id) {
    final count = _open[id];
    if (count == null) return;
    if (count <= 1) {
      _open.remove(id);
      _closed.add(id);
    } else {
      _open[id] = count - 1;
    }
  }

  bool contains(String id) => _open.containsKey(id);

  Set<String> snapshot() => Set<String>.unmodifiable(_open.keys);

  /// 正处于编辑模式的日记；与“打开”不同，只读停留不算。
  final Set<String> _editing = <String>{};
  final StreamController<String> _editingEnded =
      StreamController<String>.broadcast();

  Stream<String> get editingEnded => _editingEnded.stream;

  void setEditing(String id, {required bool editing}) {
    if (id.isEmpty) return;
    if (editing) {
      _editing.add(id);
    } else if (_editing.remove(id)) {
      _editingEnded.add(id);
    }
  }

  Set<String> editingSnapshot() => Set<String>.unmodifiable(_editing);
}
