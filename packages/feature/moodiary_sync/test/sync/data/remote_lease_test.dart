import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_sync/src/data/remote_lease.dart';

Uint8List _bytes(Object json) => .fromList(utf8.encode(jsonEncode(json)));

void main() {
  group('LeasePayload', () {
    test('round-trips through toBytes/fromBytes', () {
      final payload = LeasePayload(
        owner: 'device-a',
        acquiredAt: .utc(2026, 6, 10, 12),
        ttl: const Duration(minutes: 5),
      );
      final restored = LeasePayload.fromBytes(payload.toBytes())!;
      expect(restored.owner, 'device-a');
      expect(restored.acquiredAt, payload.acquiredAt);
      expect(restored.ttl, payload.ttl);
    });

    test('malformed payloads return null', () {
      expect(LeasePayload.fromBytes(_bytes('not-a-map')), isNull);
      expect(LeasePayload.fromBytes(_bytes({'owner': ''})), isNull);
      expect(
        LeasePayload.fromBytes(
          _bytes({'owner': 'a', 'acquiredAt': 'bad', 'ttlSeconds': 300}),
        ),
        isNull,
      );
      expect(
        LeasePayload.fromBytes(
          _bytes({
            'owner': 'a',
            'acquiredAt': '2026-06-10T00:00:00Z',
            'ttlSeconds': 0,
          }),
        ),
        isNull,
      );
      expect(LeasePayload.fromBytes(.fromList([0xff, 0x00, 0x01])), isNull);
    });

    test('isExpired honors ttl plus clock-skew margin', () {
      final acquiredAt = DateTime.utc(2026, 6, 10, 12);
      final payload = LeasePayload(
        owner: 'device-a',
        acquiredAt: acquiredAt,
        ttl: const Duration(minutes: 5),
      );
      final expiryWithMargin = acquiredAt
          .add(const Duration(minutes: 5))
          .add(RemoteLease.clockSkewMargin);
      expect(payload.isExpired(acquiredAt), isFalse);
      expect(
        payload.isExpired(
          expiryWithMargin.subtract(const Duration(seconds: 1)),
        ),
        isFalse,
        reason: 'ttl 已过但仍在时钟偏差余量内，不得判为过期',
      );
      expect(
        payload.isExpired(expiryWithMargin.add(const Duration(seconds: 1))),
        isTrue,
      );
    });
  });
}
