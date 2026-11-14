part of '../editor.dart';

class _LruMap<K, V> {
  _LruMap(this.capacity, {this.onEvict});

  final int capacity;
  final void Function(K key, V value)? onEvict;
  final _values = <K, V>{};

  Iterable<MapEntry<K, V>> get entries => _values.entries;

  V? operator [](K key) {
    final value = _values.remove(key);
    if (value != null) _values[key] = value;
    return value;
  }

  void operator []=(K key, V value) {
    _values.remove(key);
    _values[key] = value;
    while (_values.length > capacity) {
      final key = _values.keys.first;
      final removed = _values.remove(key);
      if (removed != null) onEvict?.call(key, removed);
    }
  }

  V putIfAbsent(K key, V Function() create) {
    final cached = this[key];
    if (cached != null) return cached;
    final value = create();
    this[key] = value;
    return value;
  }

  V? remove(K key) => _values.remove(key);
  void clear() => _values.clear();
}
