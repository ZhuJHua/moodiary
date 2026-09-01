import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';

void main() {
  group('SyncEvent', () {
    test('round-trips through toJson/fromJson', () {
      final event = SyncEvent(
        at: .utc(2026, 6, 10, 12, 30),
        level: .warn,
        kind: .diaryUpload,
        reason: .upToDate,
        payload: {'diaryId': 'x', 'bytes': 12},
      );
      final restored = SyncEvent.fromJson(event.toJson());
      expect(restored.at, event.at);
      expect(restored.level, SyncEventLevel.warn);
      expect(restored.kind, SyncEventKind.diaryUpload);
      expect(restored.reason, SyncEventReason.upToDate);
      expect(restored.payload, {'diaryId': 'x', 'bytes': 12});
    });

    test('omits empty payload and absent reason in json', () {
      final json = SyncEvent.now(
        level: .info,
        kind: .syncStart,
      ).toJson();
      expect(json.containsKey('payload'), isFalse);
      expect(json.containsKey('reason'), isFalse);
    });

    test('tolerant parse: unknown level/kind and bad time fall back', () {
      final restored = SyncEvent.fromJson({
        'at': 'not-a-date',
        'level': 'bogus',
        'kind': 'bogus',
      });
      expect(restored.level, SyncEventLevel.info);
      expect(restored.kind, SyncEventKind.error);
      expect(restored.at, DateTime.fromMillisecondsSinceEpoch(0));
      expect(restored.reason, isNull);
    });

    test('unknown reason parses to null, legacy message ignored', () {
      final restored = SyncEvent.fromJson({
        'level': 'info',
        'kind': 'syncEnd',
        'reason': 'bogus',
        'message': 'legacy line',
      });
      expect(restored.reason, isNull);
    });
  });
}
