import 'package:flutter/foundation.dart';

@internal
class MediaCache<CacheKey, CacheValue extends Object> {
  MediaCache({this.capacity = 512});

  final int capacity;
  final _entries = <CacheKey, CacheValue>{};

  CacheValue? operator [](CacheKey key) {
    final value = _entries.remove(key);
    if (value != null) _entries[key] = value;
    return value;
  }

  void operator []=(CacheKey key, CacheValue value) {
    _entries.remove(key);
    _entries[key] = value;
    if (_entries.length > capacity) _entries.remove(_entries.keys.first);
  }

  void clear() => _entries.clear();

  void remove(CacheKey key) => _entries.remove(key);
}
