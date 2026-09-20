import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_sync/src/application/re_cipher.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';

import '../sync_test_harness.dart';

void main() {
  late SyncLogger logger;

  setUp(() async {
    logger = (await setUpSyncEnv()).logger;
  });
  tearDown(tearDownSyncEnv);

  Uint8List jsonBytes(Object v) => .fromList(utf8.encode(jsonEncode(v)));

  Uint8List manifestBytes(String writeToken) => jsonBytes({
    'version': SyncManifest.currentVersion,
    'updatedAt': 1,
    'w': writeToken,
    'entries': {
      'd:a': {'t': 100},
    },
  });

  test('别人先写 → 翻转 manifest 前中止，对方的索引原样保留', () async {
    final backend = FakeRemoteBackend();
    backend.objects[SyncKeys.manifestPath] = manifestBytes('mine');
    backend.objects[SyncKeys.diaryObjectPath('a')] = jsonBytes({'id': 'a'});

    backend.beforeOp = (op, key) {
      if (op == 'read' && key == SyncKeys.diaryObjectPath('a')) {
        backend.objects[SyncKeys.manifestPath] = manifestBytes('another-device');
      }
    };

    await expectLater(
      CloudReCipher(backend, logger: logger).run(
        from: SyncCipher.withKey(List.filled(32, 1)),
        to: SyncCipher.plaintext,
      ),
      throwsA(
        isA<SyncException>().having(
          (e) => e.kind,
          'kind',
          SyncErrorKind.manifestRace,
        ),
      ),
    );
    expect(backend.manifest()!.writeToken, 'another-device');
  });

  test('已是目标形态的对象不再重传', () async {
    final backend = FakeRemoteBackend();
    backend.objects[SyncKeys.manifestPath] = manifestBytes('mine');
    backend.objects[SyncKeys.diaryObjectPath('a')] = jsonBytes({'id': 'a'});

    await CloudReCipher(backend, logger: logger).run(
      from: SyncCipher.withKey(List.filled(32, 1)),
      to: SyncCipher.plaintext,
    );

    expect(
      backend.opCount('write', SyncKeys.diaryObjectPath('a')),
      0,
      reason: '远端已是明文，重跑不得再写一遍',
    );
  });
}
