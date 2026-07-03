import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';

void main() {
  group('SyncEvent', () {
    test('round-trips through toJson/fromJson', () {
      final event = SyncEvent(
        at: DateTime.utc(2026, 6, 10, 12, 30),
        level: SyncEventLevel.warn,
        kind: SyncEventKind.diaryUpload,
        message: 'hi',
        payload: {'diaryId': 'x', 'bytes': 12},
      );
      final restored = SyncEvent.fromJson(event.toJson());
      expect(restored.at, event.at);
      expect(restored.level, SyncEventLevel.warn);
      expect(restored.kind, SyncEventKind.diaryUpload);
      expect(restored.message, 'hi');
      expect(restored.payload, {'diaryId': 'x', 'bytes': 12});
    });

    test('omits empty payload in json', () {
      final json = SyncEvent.now(
        level: SyncEventLevel.info,
        kind: SyncEventKind.syncStart,
        message: 'm',
      ).toJson();
      expect(json.containsKey('payload'), isFalse);
    });

    test('tolerant parse: unknown level/kind and bad time fall back', () {
      final restored = SyncEvent.fromJson({
        'at': 'not-a-date',
        'level': 'bogus',
        'kind': 'bogus',
        'message': 'm',
      });
      expect(restored.level, SyncEventLevel.info);
      expect(restored.kind, SyncEventKind.error);
      expect(restored.at, DateTime.fromMillisecondsSinceEpoch(0));
      expect(restored.message, 'm');
    });

    test('missing message becomes empty string', () {
      final restored = SyncEvent.fromJson({'level': 'info', 'kind': 'syncEnd'});
      expect(restored.message, '');
    });
  });
}
