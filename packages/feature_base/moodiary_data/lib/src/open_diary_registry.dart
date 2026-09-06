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
}
