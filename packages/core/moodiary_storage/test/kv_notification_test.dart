import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_storage/testing.dart';

void main() {
  for (final clear in [false, true]) {
    test(
      '${clear ? 'clear' : 'remove'} restores fallback and preserves subscriptions',
      () {
        final storage = MemoryKVStorage()..set('key', 4);
        final notifier = storage.getNotifier('key', 2);
        final values = <int>[];
        notifier.addListener(() => values.add(notifier.value));
        if (clear) {
          storage.clear();
        } else {
          storage.remove('key');
        }
        expect(storage.get<int>('key'), isNull);
        storage.set('key', 7);
        expect(values, [2, 7]);
        expect(storage.getNotifier('key', 2), same(notifier));
      },
    );
  }
}
