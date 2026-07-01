import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/feature/sync/data/model/manifest.dart';
import 'package:moodiary/feature/sync/data/sync.dart';

void main() {
  group('ManifestEntry', () {
    test('normal entry round-trips time and media', () {
      const entry = ManifestEntry(
        timeMs: 1780000000000,
        media: ['image/a.png', 'video/v.mp4', 'video/thumbnail-x.jpeg'],
      );
      final restored = ManifestEntry.fromJson(
        jsonDecode(jsonEncode(entry.toJson())),
      )!;
      expect(restored.timeMs, entry.timeMs);
      expect(restored.deleted, isFalse);
      expect(restored.media, entry.media);
    });

    test('LWW compare against local diary works on plain ints', () {
      // 本地 lastModified 带微秒（Isar 按微秒存）；LWW 全程比毫秒 int，
      // 同版本「本地不晚于远端」必须成立，否则每次 push 全量重传。
      final localMicros = DateTime.fromMicrosecondsSinceEpoch(
        1780000000123456,
        isUtc: true,
      );
      final entry = ManifestEntry(
        timeMs: localMicros.millisecondsSinceEpoch,
      );
      final restored = ManifestEntry.fromJson(
        jsonDecode(jsonEncode(entry.toJson())),
      )!;
      // 模拟 push 的跳过判断
      expect(
        localMicros.millisecondsSinceEpoch <= restored.timeMs,
        isTrue,
      );
    });

    test('tombstone round-trips deleted flag and omits media', () {
      const entry = ManifestEntry(timeMs: 1780000000000, deleted: true);
      final json = entry.toJson();
      expect(json.containsKey('m'), isFalse);
      final restored = ManifestEntry.fromJson(json)!;
      expect(restored.deleted, isTrue);
      expect(restored.media, isEmpty);
    });

    test('malformed entries return null', () {
      expect(ManifestEntry.fromJson(1780000000000), isNull);
      expect(
        ManifestEntry.fromJson({'t': '2026-01-01T00:00:00Z'}),
        isNull,
        reason: 'ISO 字符串形式不再接受，时间必须是整数毫秒',
      );
      expect(ManifestEntry.fromJson({'d': true}), isNull);
      expect(ManifestEntry.fromJson(null), isNull);
    });
  });

  group('SyncManifest', () {
    Map<String, dynamic> validJson() => {
      'version': SyncManifest.currentVersion,
      'updatedAt': 1780000000000,
      'entries': <String, dynamic>{
        'd:one': {
          't': 1780000001000,
          'm': ['image/a.png', 'audio/b.m4a'],
        },
        'd:gone': {'t': 1780000002000, 'd': true},
        'c:cat': {'t': 1780000003000},
      },
    };

    test('round-trips through toJson/fromJson', () {
      final manifest = SyncManifest.fromJson(validJson());
      final restored = SyncManifest.fromJson(
        jsonDecode(jsonEncode(manifest.toJson())),
      );
      expect(restored.entries.length, 3);
      expect(restored.entries['d:one']!.media, ['image/a.png', 'audio/b.m4a']);
      expect(restored.entries['d:gone']!.deleted, isTrue);
      expect(restored.entries['c:cat']!.media, isEmpty);
    });

    test('rejects other versions (older and newer)', () {
      for (final version in [0, 3, SyncManifest.currentVersion + 1]) {
        final json = validJson()..['version'] = version;
        expect(
          () => SyncManifest.fromJson(json),
          throwsA(isA<SyncException>()),
          reason: 'version $version must be rejected',
        );
      }
      expect(
        () => SyncManifest.fromJson(validJson()..remove('version')),
        throwsA(isA<SyncException>()),
      );
    });

    test('non-int version throws SyncException, not a raw TypeError', () {
      for (final bad in ['4', 4.0, true]) {
        expect(
          () => SyncManifest.fromJson(validJson()..['version'] = bad),
          throwsA(isA<SyncException>()),
          reason: 'version $bad (${bad.runtimeType}) must throw SyncException',
        );
      }
    });

    test('corrupt entries field (non-Map) throws instead of yielding empty', () {
      for (final bad in ['oops', 5, <dynamic>[]]) {
        expect(
          () => SyncManifest.fromJson(validJson()..['entries'] = bad),
          throwsA(isA<SyncException>()),
          reason: 'entries $bad must be rejected, never silently empty',
        );
      }
      // 缺失 entries 仍合法（视作空清单）。
      final m = SyncManifest.fromJson(validJson()..remove('entries'));
      expect(m.entries, isEmpty);
    });

    test('drops malformed entries instead of failing whole manifest', () {
      final json = validJson();
      (json['entries'] as Map<String, dynamic>)['d:bad'] = 'deleted@legacy';
      final manifest = SyncManifest.fromJson(json);
      expect(manifest.entries.containsKey('d:bad'), isFalse);
      expect(manifest.entries.length, 3);
    });

    test('referencedMedia unions non-tombstone entries only', () {
      final json = validJson();
      (json['entries'] as Map<String, dynamic>)['d:gone'] = {
        't': 1780000002000,
        'd': true,
        'm': ['image/from-tombstone.png'],
      };
      (json['entries'] as Map<String, dynamic>)['d:two'] = {
        't': 1780000004000,
        'm': ['image/a.png', 'video/v.mp4'],
      };
      final media = SyncManifest.fromJson(json).referencedMedia();
      expect(media, {'image/a.png', 'audio/b.m4a', 'video/v.mp4'});
    });

    test('copyForUpdate isolates entry map mutations', () {
      final manifest = SyncManifest.fromJson(validJson());
      final updated = manifest.copyForUpdate();
      updated.entries['d:new'] = const ManifestEntry(timeMs: 1780000005000);
      updated.entries.remove('d:one');
      expect(manifest.entries.containsKey('d:new'), isFalse);
      expect(manifest.entries.containsKey('d:one'), isTrue);
    });
  });
}
