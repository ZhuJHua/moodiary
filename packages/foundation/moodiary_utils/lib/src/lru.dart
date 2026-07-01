import 'dart:collection';

import 'package:synchronized/synchronized.dart';

class LRUCache<K, V> {
  final int maxSize;
  final LinkedHashMap<K, V> _map;

  LRUCache({this.maxSize = 1000}) : _map = LinkedHashMap<K, V>();

  V? get(K key) {
    if (!_map.containsKey(key)) return null;
    final value = _map.remove(key) as V;
    _map[key] = value;
    return value;
  }

  void put(K key, V value) {
    if (_map.containsKey(key)) {
      _map.remove(key);
    } else if (_map.length >= maxSize) {
      _map.remove(_map.keys.first);
    }
    _map[key] = value;
  }

  void clear() => _map.clear();

  int size() => _map.length;

  @override
  String toString() => _map.toString();
}

class AsyncLRUCache<K, V> {
  final int maxSize;
  final LinkedHashMap<K, V> _map = LinkedHashMap<K, V>();
  final Lock _lock = Lock();

  AsyncLRUCache({this.maxSize = 1000});

  Future<V?> get(K key) async {
    return await _lock.synchronized(() async {
      if (!_map.containsKey(key)) return null;
      final value = _map.remove(key) as V;
      _map[key] = value;
      return value;
    });
  }

  Future<void> put(K key, V value) async {
    await _lock.synchronized(() async {
      if (_map.containsKey(key)) {
        _map.remove(key);
      } else if (_map.length >= maxSize) {
        _map.remove(_map.keys.first);
      }
      _map[key] = value;
    });
  }

  Future<void> clear() async {
    await _lock.synchronized(() => _map.clear());
  }

  Future<int> size() async {
    return await _lock.synchronized(() => _map.length);
  }

  @override
  String toString() => _map.toString();
}
