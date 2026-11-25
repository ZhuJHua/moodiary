import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_sync/src/application/re_cipher.dart';
import 'package:moodiary_sync/src/application/sync_operation_guard.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';

import '../sync_test_harness.dart';

class _TestCipher extends SyncCipher {
  const _TestCipher() : super.withKey(const []);

  @override
  Future<Uint8List> encode(Object value) async => Uint8List.fromList([
    ...utf8.encode(SyncCipher.magic),
    ...await SyncCipher.plaintext.encode(value),
  ]);

  @override
  Future<dynamic> decode(Uint8List bytes) => SyncCipher.plaintext.decode(
    SyncCipher.isCipherText(bytes)
        ? bytes.sublist(SyncCipher.magic.length)
        : bytes,
  );
}

void main() {
  late SyncTestEnv env;
  late SyncOperation operation;
  late SyncLogger logger;
  late Directory cacheRoot;

  setUpAll(() {
    cacheRoot = Directory.systemTemp.createTempSync('re-cipher-cache');
    PlatformService.get().applicationCachePath = cacheRoot.path;
  });

  tearDownAll(() => cacheRoot.deleteSync(recursive: true));

  setUp(() async {
    env = await setUpSyncEnv();
    logger = env.logger;
    operation = env.guard.tryAcquire()!;
    addTearDown(operation.release);
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

  test(
    're-cipher converts tag objects both ways and reports missing objects',
    () async {
      final backend = FakeRemoteBackend();
      backend.objects[SyncKeys.manifestPath] = jsonBytes({
        'version': 4,
        'entries': {
          't:a': {'t': 1},
          't:missing': {'t': 2},
        },
      });
      final path = SyncKeys.tagObjectPath('a');
      final data = {'id': 'a', 'deleted': true};
      backend.objects[path] = jsonBytes(data);
      const encrypted = _TestCipher();
      final converter = CloudReCipher(backend, logger);
      final forward = await converter.run(
        operation,
        from: SyncCipher.plaintext,
        to: encrypted,
      );
      expect(forward!.tagCount, 1);
      expect(forward.failed, 1);
      expect(SyncCipher.isCipherText(backend.objects[path]!), isTrue);
      final reverse = await converter.run(
        operation,
        from: encrypted,
        to: SyncCipher.plaintext,
      );
      expect(reverse!.tagCount, 1);
      expect(reverse.failed, 1);
      expect(await SyncCipher.plaintext.decode(backend.objects[path]!), data);
    },
  );

  test('别人先写 → 翻转 manifest 前中止，对方的索引原样保留', () async {
    final backend = FakeRemoteBackend();
    backend.objects[SyncKeys.manifestPath] = manifestBytes('mine');
    backend.objects[SyncKeys.diaryObjectPath('a')] = jsonBytes({'id': 'a'});

    backend.beforeOp = (op, key) {
      if (op == 'read' && key == SyncKeys.diaryObjectPath('a')) {
        backend.objects[SyncKeys.manifestPath] = manifestBytes(
          'another-device',
        );
      }
    };

    await expectLater(
      CloudReCipher(backend, logger).run(
        operation,
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

  test('已转换的日记仍要贡献媒体引用（v1 旧清单没有 per-entry 列表）', () async {
    final backend = FakeRemoteBackend();
    backend.objects[SyncKeys.manifestPath] = manifestBytes('mine');
    backend.objects[SyncKeys.diaryObjectPath('a')] = jsonBytes({
      'id': 'a',
      'imageName': ['p.jpg'],
    });
    backend.objects['media/image/p.jpg'] = Uint8List.fromList([1, 2, 3]);

    await CloudReCipher(backend, logger).run(
      operation,
      from: SyncCipher.withKey(List.filled(32, 1)),
      to: SyncCipher.plaintext,
    );

    expect(
      backend.opCount('read', 'media/image/p.jpg'),
      greaterThan(0),
      reason: '跳过重传不等于跳过收集媒体引用',
    );
  });

  test('附件（fileName）与其它媒体一样被收集并转换', () async {
    final backend = FakeRemoteBackend();
    backend.objects[SyncKeys.manifestPath] = manifestBytes('mine');
    backend.objects[SyncKeys.diaryObjectPath('a')] = jsonBytes({
      'id': 'a',
      'fileName': ['file-a.pdf'],
    });
    backend.objects['media/file/file-a.pdf'] = Uint8List.fromList([1, 2, 3]);

    await CloudReCipher(backend, logger).run(
      operation,
      from: SyncCipher.withKey(List.filled(32, 1)),
      to: SyncCipher.plaintext,
    );

    expect(backend.opCount('read', 'media/file/file-a.pdf'), greaterThan(0));
  });

  test('已是目标形态的对象不再重传', () async {
    final backend = FakeRemoteBackend();
    backend.objects[SyncKeys.manifestPath] = manifestBytes('mine');
    backend.objects[SyncKeys.diaryObjectPath('a')] = jsonBytes({'id': 'a'});

    await CloudReCipher(backend, logger).run(
      operation,
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
