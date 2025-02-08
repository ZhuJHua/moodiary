import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/utils/lru.dart';

void main() {
  test('lru cache test', () {
    final lru = LRUCache<int, int>(maxSize: 3);
    lru.put(1, 1);
    lru.put(2, 2);
    lru.put(3, 3);
    expect(lru.size(), 3);
    lru.put(4, 4);
    expect(lru.size(), 3);
    expect(lru.get(1), null);
    expect(lru.get(2), 2);
    lru.put(5, 5);
    expect(lru.size(), 3);
    expect(lru.get(3), null);
    expect(lru.get(4), 4);
    expect(lru.get(5), 5);
  });
}
