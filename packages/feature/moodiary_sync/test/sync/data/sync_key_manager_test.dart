import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_sync/src/application/remote_wipe.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_key_manager.dart';
import 'package:moodiary_sync/src/data/sync_keyfile.dart';

import '../sync_test_harness.dart';

Future<List<int>> fakeDerive({
  required String salt,
  required String passphrase,
  required int mCostKib,
  required int tCost,
  required int pCost,
}) async {
  final seed = utf8.encode('$salt|$passphrase|$mCostKib|$tCost|$pCost');
  final out = List<int>.filled(32, 7);
  for (var i = 0; i < seed.length; i++) {
    out[i % 32] = (out[i % 32] * 31 + seed[i]) & 0xff;
  }
  return out;
}

int _checksum(List<int> key) => key.fold(0, (a, b) => (a + b) & 0xff);

Future<List<int>> fakeEncrypt({
  required List<int> key,
  required List<int> data,
}) async => [
  _checksum(key),
  for (var i = 0; i < data.length; i++) data[i] ^ key[i % key.length],
];

Future<List<int>> fakeDecrypt({
  required List<int> key,
  required List<int> data,
}) async {
  if (data.isEmpty || data.first != _checksum(key)) {
    throw Exception('auth tag mismatch');
  }
  final body = data.sublist(1);
  return [for (var i = 0; i < body.length; i++) body[i] ^ key[i % key.length]];
}

void main() {
  setUp(() async {
    await setUpSyncEnv();
    SyncKeyManager.deriveKey = fakeDerive;
    SyncKeyManager.aeadEncrypt = fakeEncrypt;
    SyncKeyManager.aeadDecrypt = fakeDecrypt;
  });

  tearDown(tearDownSyncEnv);

  group('claimRemoteKeyfile', () {
    const mine = SyncKeyfile(
      kdfMemoryKiB: 65536,
      kdfIterations: 3,
      kdfParallelism: 4,
      saltB64: 'bWluZQ==',
      wrappedDekB64: 'bWluZQ==',
    );
    const theirs = SyncKeyfile(
      kdfMemoryKiB: 65536,
      kdfIterations: 3,
      kdfParallelism: 4,
      saltB64: 'dGhlaXJz',
      wrappedDekB64: 'dGhlaXJz',
    );

    test('虚拟远端 → 占位成功', () async {
      final backend = FakeRemoteBackend();
      expect(await SyncKeyManager.claimRemoteKeyfile(backend, mine), isTrue);
      expect(
        SyncKeyfile.fromBytes(backend.objects[SyncKeys.keysPath]!).saltB64,
        mine.saltB64,
      );
    });

    test('被别的设备抢先 → 占位失败且不覆盖对方的信封', () async {
      final backend = FakeRemoteBackend();
      backend.beforeOp = (op, key) {
        if (op == 'create' && key == SyncKeys.keysPath) {
          backend.objects[key] = theirs.toBytes();
        }
      };
      expect(await SyncKeyManager.claimRemoteKeyfile(backend, mine), isFalse);
      expect(
        SyncKeyfile.fromBytes(backend.objects[SyncKeys.keysPath]!).saltB64,
        theirs.saltB64,
      );
    });

    test('远端数据已是明文时，陈旧信封要被顶掉（否则加密再也开不回来）', () async {
      final backend = FakeRemoteBackend();
      backend.objects[SyncKeys.keysPath] = theirs.toBytes();
      expect(
        await SyncKeyManager.claimRemoteKeyfile(
          backend,
          mine,
          replaceStale: true,
        ),
        isTrue,
      );
      expect(
        SyncKeyfile.fromBytes(backend.objects[SyncKeys.keysPath]!).saltB64,
        mine.saltB64,
      );
    });

    test('服务端不支持条件写 → 仍不覆盖已有信封', () async {
      final backend = FakeRemoteBackend()..conditionalPutSupported = false;
      backend.objects[SyncKeys.keysPath] = theirs.toBytes();
      expect(await SyncKeyManager.claimRemoteKeyfile(backend, mine), isFalse);
      expect(
        SyncKeyfile.fromBytes(backend.objects[SyncKeys.keysPath]!).saltB64,
        theirs.saltB64,
      );
    });
  });

  group('SyncKeyfile JSON', () {
    const keyfile = SyncKeyfile(
      kdfMemoryKiB: 65536,
      kdfIterations: 3,
      kdfParallelism: 4,
      saltB64: 'c2FsdA==',
      wrappedDekB64: 'd3JhcHBlZA==',
    );

    test('toJson → fromJson 往返', () {
      final restored = SyncKeyfile.fromJson(keyfile.toJson());
      expect(restored.saltB64, keyfile.saltB64);
      expect(restored.wrappedDekB64, keyfile.wrappedDekB64);
      expect(restored.kdfMemoryKiB, 65536);
      expect(restored.kdfIterations, 3);
      expect(restored.kdfParallelism, 4);
    });

    test('更高版本拒绝（防静默丢字段）', () {
      final json = keyfile.toJson()..['version'] = 99;
      expect(() => SyncKeyfile.fromJson(json), throwsA(isA<SyncException>()));
    });

    test('KDF 参数超限拒绝（keys.json 是不可信输入，防内存炸弹 DoS）', () {
      final json = keyfile.toJson();
      (json['kdf'] as Map)['mKiB'] = 4 * 1024 * 1024;
      expect(() => SyncKeyfile.fromJson(json), throwsA(isA<SyncException>()));
      (json['kdf'] as Map)['mKiB'] = 65536;
      (json['kdf'] as Map)['t'] = 0;
      expect(() => SyncKeyfile.fromJson(json), throwsA(isA<SyncException>()));
    });

    test('损坏内容拒绝', () {
      expect(
        () => SyncKeyfile.fromBytes(.fromList(utf8.encode('[]'))),
        throwsA(isA<SyncException>()),
      );
      expect(
        () => SyncKeyfile.fromBytes(.fromList(utf8.encode('{"version":1}'))),
        throwsA(isA<SyncException>()),
      );
    });
  });

  group('wrap / unwrap', () {
    test('正确密码往返出同一 DEK；盐随机不重复', () async {
      final dek = SyncKeyManager.generateDek();
      final kf1 = await SyncKeyManager.wrapDek(dek: dek, passphrase: 'p1');
      final kf2 = await SyncKeyManager.wrapDek(dek: dek, passphrase: 'p1');
      expect(kf1.saltB64, isNot(kf2.saltB64), reason: '每次包装都用新随机盐');

      final out = await SyncKeyManager.unwrapDek(
        keyfile: kf1,
        passphrase: 'p1',
      );
      expect(out, dek);
    });

    test('密码错误抛 SyncException（模拟 GCM tag 失败）', () async {
      final dek = SyncKeyManager.generateDek();
      final kf = await SyncKeyManager.wrapDek(dek: dek, passphrase: 'right');
      expect(
        () => SyncKeyManager.unwrapDek(keyfile: kf, passphrase: 'wrong'),
        throwsA(isA<SyncException>()),
      );
    });

    test('解包按 keyfile 所记 KDF 参数派生（参数不同 → KEK 不同）', () async {
      final dek = SyncKeyManager.generateDek();
      final kf = await SyncKeyManager.wrapDek(dek: dek, passphrase: 'p');
      final tampered = SyncKeyfile(
        kdfMemoryKiB: kf.kdfMemoryKiB * 2,
        kdfIterations: kf.kdfIterations,
        kdfParallelism: kf.kdfParallelism,
        saltB64: kf.saltB64,
        wrappedDekB64: kf.wrappedDekB64,
      );
      expect(
        () => SyncKeyManager.unwrapDek(keyfile: tampered, passphrase: 'p'),
        throwsA(isA<SyncException>()),
      );
    });

    test('generateDek 每次不同且 32 字节', () {
      final a = SyncKeyManager.generateDek();
      final b = SyncKeyManager.generateDek();
      expect(a.length, 32);
      expect(a, isNot(b));
    });
  });

  group('本机 DEK 与 keyfile 缓存', () {
    test('storeDek → loadDek → clearDek 生命周期', () async {
      expect(await SyncKeyManager.loadDek(), isNull);
      final dek = SyncKeyManager.generateDek();
      await SyncKeyManager.storeDek(dek);
      expect(await SyncKeyManager.loadDek(), dek);
      expect((await SyncKeyManager.currentCipher()).encrypted, isTrue);

      await SyncKeyManager.clearDek();
      expect(await SyncKeyManager.loadDek(), isNull);
      expect(SyncKeyManager.cachedKeyfile(), isNull);
      expect(SyncKeyManager.pendingUploadBackends(), isEmpty);
    });

    test('installKey 只在换了 DEK 时标记媒体强制重传', () async {
      const keyfile = SyncKeyfile(
        kdfMemoryKiB: 65536,
        kdfIterations: 3,
        kdfParallelism: 4,
        saltB64: 'cw==',
        wrappedDekB64: 'dw==',
      );
      Future<void> install(List<int> dek) => SyncKeyManager.installKey(
        dek: dek,
        keyfile: keyfile,
        backendId: 'b1',
        configured: {'b1', 'b2'},
      );
      final dek = SyncKeyManager.generateDek();
      SyncKeyManager.markKeyConflict('b1');
      await install(dek);
      expect(SyncKeyManager.hasForceMediaReupload('b1'), isFalse);
      expect(SyncKeyManager.hasKeyConflict('b1'), isFalse);
      expect(SyncKeyManager.pendingUploadBackends(), ['b2']);
      await install([...dek]);
      expect(SyncKeyManager.hasForceMediaReupload('b1'), isFalse);
      await install(SyncKeyManager.generateDek());
      expect(SyncKeyManager.hasForceMediaReupload('b1'), isTrue);
    });

    test('cacheKeyfile 往返；损坏缓存按不存在处理', () async {
      final dek = SyncKeyManager.generateDek();
      final kf = await SyncKeyManager.wrapDek(dek: dek, passphrase: 'p');
      SyncKeyManager.cacheKeyfile(kf);
      expect(SyncKeyManager.cachedKeyfile()?.wrappedDekB64, kf.wrappedDekB64);

      MoodiaryKVs.syncKeyfileCache.set('not-json');
      expect(SyncKeyManager.cachedKeyfile(), isNull);
    });
  });

  group('待上传清单与补传', () {
    test('mark / clear 合并去重', () async {
      await SyncKeyManager.markPendingUpload(['webdav']);
      await SyncKeyManager.markPendingUpload(['webdav', 's3']);
      expect(SyncKeyManager.pendingUploadBackends().toSet(), {'webdav', 's3'});
      await SyncKeyManager.clearPendingUpload('webdav');
      expect(SyncKeyManager.pendingUploadBackends(), ['s3']);
    });

    test('uploadPendingKeyfile：pending 命中才写远端，成功后出清单', () async {
      final backend = FakeRemoteBackend();
      await SyncKeyManager.uploadPendingKeyfile(backend);
      expect(backend.ops, isEmpty);

      final dek = SyncKeyManager.generateDek();
      final kf = await SyncKeyManager.wrapDek(dek: dek, passphrase: 'p');
      SyncKeyManager.cacheKeyfile(kf);
      await SyncKeyManager.markPendingUpload(['webdav']);

      await SyncKeyManager.uploadPendingKeyfile(backend);
      expect(backend.hasObject(SyncKeys.keysPath), isTrue);
      expect(SyncKeyManager.pendingUploadBackends(), isEmpty);

      final remote = SyncKeyfile.fromBytes(backend.objects[SyncKeys.keysPath]!);
      expect(remote.wrappedDekB64, kf.wrappedDekB64);
    });

    test('pending 但无缓存 keyfile：直接出清单不写远端', () async {
      final backend = FakeRemoteBackend();
      await SyncKeyManager.markPendingUpload(['webdav']);
      await SyncKeyManager.uploadPendingKeyfile(backend);
      expect(backend.ops, isEmpty);
      expect(SyncKeyManager.pendingUploadBackends(), isEmpty);
    });
  });

  group('checkRemoteKeyfile', () {
    Uint8List cipherTextBytes() =>
        Uint8List.fromList([...utf8.encode(SyncCipher.magic), 1, 2, 3]);

    test('远端没有信封 → safe（写入即初始化，孤立不了东西）', () async {
      final backend = FakeRemoteBackend();
      expect(
        await SyncKeyManager.checkRemoteKeyfile(backend),
        RemoteKeyfileCheck.safe,
      );
    });

    test('远端有信封但 manifest 是明文 → safe（没有密文可作废）', () async {
      final backend = FakeRemoteBackend();
      final kf = await SyncKeyManager.wrapDek(
        dek: SyncKeyManager.generateDek(),
        passphrase: 'p',
      );
      backend.objects[SyncKeys.keysPath] = kf.toBytes();
      backend.objects[SyncKeys.manifestPath] = Uint8List.fromList(
        utf8.encode('{"version":4}'),
      );
      expect(
        await SyncKeyManager.checkRemoteKeyfile(backend),
        RemoteKeyfileCheck.safe,
      );
    });

    test('远端有信封 + 密文 manifest，而本机没有 DEK → conflict', () async {
      final backend = FakeRemoteBackend();
      final kf = await SyncKeyManager.wrapDek(
        dek: SyncKeyManager.generateDek(),
        passphrase: 'p',
      );
      backend.objects[SyncKeys.keysPath] = kf.toBytes();
      backend.objects[SyncKeys.manifestPath] = cipherTextBytes();
      expect(
        await SyncKeyManager.checkRemoteKeyfile(backend),
        RemoteKeyfileCheck.conflict,
      );
    });

    test('远端读失败 → unknown（判不出来就不写）', () async {
      final backend = FakeRemoteBackend()
        ..beforeOp = (op, key) {
          if (op == 'read') throw const SyncException('offline');
        };
      expect(
        await SyncKeyManager.checkRemoteKeyfile(backend),
        RemoteKeyfileCheck.unknown,
      );
    });

    test('冲突时补传不写远端、抛冲突异常、挂标记且 pending 保留', () async {
      final backend = FakeRemoteBackend();
      final foreign = await SyncKeyManager.wrapDek(
        dek: SyncKeyManager.generateDek(),
        passphrase: 'other',
      );
      backend.objects[SyncKeys.keysPath] = foreign.toBytes();
      backend.objects[SyncKeys.manifestPath] = cipherTextBytes();

      final mine = await SyncKeyManager.wrapDek(
        dek: SyncKeyManager.generateDek(),
        passphrase: 'mine',
      );
      SyncKeyManager.cacheKeyfile(mine);
      await SyncKeyManager.markPendingUpload(['webdav']);

      await expectLater(
        SyncKeyManager.uploadPendingKeyfile(backend),
        throwsA(isA<SyncKeyConflictException>()),
      );
      expect(
        SyncKeyfile.fromBytes(backend.objects[SyncKeys.keysPath]!)
            .wrappedDekB64,
        foreign.wrappedDekB64,
      );
      expect(SyncKeyManager.hasKeyConflict('webdav'), isTrue);
      expect(SyncKeyManager.pendingUploadBackends(), ['webdav']);
    });

    test('远端不可达时补传不写、不挂标记、pending 保留', () async {
      final backend = FakeRemoteBackend()
        ..beforeOp = (op, key) {
          if (op == 'read') throw const SyncException('offline');
        };
      final kf = await SyncKeyManager.wrapDek(
        dek: SyncKeyManager.generateDek(),
        passphrase: 'p',
      );
      SyncKeyManager.cacheKeyfile(kf);
      await SyncKeyManager.markPendingUpload(['webdav']);

      await SyncKeyManager.uploadPendingKeyfile(backend);
      expect(backend.hasObject(SyncKeys.keysPath), isFalse);
      expect(SyncKeyManager.hasKeyConflict('webdav'), isFalse);
      expect(SyncKeyManager.pendingUploadBackends(), ['webdav']);
    });

    test('补传成功清掉旧的冲突标记（问题解决后别把自动同步永久停掉）', () async {
      final backend = FakeRemoteBackend();
      final kf = await SyncKeyManager.wrapDek(
        dek: SyncKeyManager.generateDek(),
        passphrase: 'p',
      );
      SyncKeyManager.cacheKeyfile(kf);
      await SyncKeyManager.markPendingUpload(['webdav']);
      SyncKeyManager.markKeyConflict('webdav');

      await SyncKeyManager.uploadPendingKeyfile(backend);
      expect(backend.hasObject(SyncKeys.keysPath), isTrue);
      expect(SyncKeyManager.hasKeyConflict('webdav'), isFalse);
      expect(SyncKeyManager.pendingUploadBackends(), isEmpty);
    });

    test('冲突标记 mark / clear / clearDek 全清', () async {
      SyncKeyManager.markKeyConflict('webdav');
      SyncKeyManager.markKeyConflict('s3');
      expect(SyncKeyManager.keyConflictBackends().toSet(), {'webdav', 's3'});
      SyncKeyManager.clearKeyConflict('webdav');
      expect(SyncKeyManager.hasKeyConflict('webdav'), isFalse);
      expect(SyncKeyManager.hasKeyConflict('s3'), isTrue);
      await SyncKeyManager.clearDek();
      expect(SyncKeyManager.keyConflictBackends(), isEmpty);
    });
  });

  group('probeRemote', () {
    test('无清单 / 明文清单 → plaintext', () async {
      final backend = FakeRemoteBackend();
      expect(
        await SyncKeyManager.probeRemote(backend),
        RemoteKeyStatus.plaintext,
      );
      backend.objects[SyncKeys.manifestPath] = await SyncCipher.plaintext
          .encode({'version': 2});
      expect(
        await SyncKeyManager.probeRemote(backend),
        RemoteKeyStatus.plaintext,
      );
    });

    test('密文清单解不开 → 有 keys.json 为 locked，没有为 keyfileMissing', () async {
      final backend = FakeRemoteBackend();
      backend.objects[SyncKeys.manifestPath] = Uint8List.fromList([
        ...utf8.encode(SyncCipher.magic),
        1,
        2,
        3,
      ]);

      await SyncKeyManager.storeDek(SyncKeyManager.generateDek());
      expect(
        await SyncKeyManager.probeRemote(backend),
        RemoteKeyStatus.keyfileMissing,
      );

      backend.objects[SyncKeys.keysPath] = (await SyncKeyManager.wrapDek(
        dek: SyncKeyManager.generateDek(),
        passphrase: 'p',
      )).toBytes();
      expect(await SyncKeyManager.probeRemote(backend), RemoteKeyStatus.locked);

      await SyncKeyManager.clearDek();
      expect(await SyncKeyManager.probeRemote(backend), RemoteKeyStatus.locked);
    });

    test('读不到远端 → unknown', () async {
      final backend = FakeRemoteBackend();
      backend.beforeOp = (op, key) => throw const SyncException('offline');
      expect(
        await SyncKeyManager.probeRemote(backend),
        RemoteKeyStatus.unknown,
      );
    });
  });

  test('remoteDecryptedElsewhere：本机有密钥、云端明文且无 keys.json 才算，待补传也不放行', () async {
    final backend = FakeRemoteBackend();
    final plain = await SyncCipher.plaintext.encode({'version': 2});
    Future<bool> check(Uint8List manifest) =>
        SyncKeyManager.remoteDecryptedElsewhere(backend, manifest);

    expect(await check(plain), isFalse);

    await SyncKeyManager.storeDek(SyncKeyManager.generateDek());
    expect(await check(plain), isTrue);
    expect(
      await check(Uint8List.fromList([...utf8.encode(SyncCipher.magic), 1])),
      isFalse,
    );
    expect(
      await SyncKeyManager.remoteDecryptedElsewhere(
        FakeRemoteBackend(backendId: 'webdav'),
        Uint8List(0),
      ),
      isFalse,
    );

    SyncKeyManager.cacheKeyfile(
      await SyncKeyManager.wrapDek(
        dek: SyncKeyManager.generateDek(),
        passphrase: 'p',
      ),
    );
    await SyncKeyManager.markPendingUpload({'webdav'});
    backend.objects[SyncKeys.manifestPath] = plain;
    await SyncKeyManager.uploadPendingKeyfile(backend);
    expect(backend.hasObject(SyncKeys.keysPath), isFalse);
    expect(SyncKeyManager.pendingUploadBackends(), ['webdav']);
    expect(await check(plain), isTrue);

    backend.objects[SyncKeys.keysPath] = (await SyncKeyManager.wrapDek(
      dek: SyncKeyManager.generateDek(),
      passphrase: 'p',
    )).toBytes();
    expect(await check(plain), isFalse);
  });

  group('RemoteWipe', () {
    test('信封无条件最先删，可疑键与锁文件不碰，删完补一份明文空清单', () async {
      final backend = FakeRemoteBackend(
        objects: {
          for (final k in [
            'diary/a.json',
            'media/image/x.jpg',
            SyncKeys.keysPath,
            'mediainfo/image/x.jpg.json',
            '../outside.db',
            'media/%2e%2e/y',
          ])
            k: Uint8List.fromList([1]),
        },
      );
      final progress = <int>[];
      final report = await RemoteWipe.run(
        backend,
        passphrase: null,
        onProgress: (done, total, _) => progress.add(done),
      );

      expect(report.deleted, 5);
      expect(report.failed, 0);
      expect(progress.last, 5);
      expect(backend.objects.keys, {
        '../outside.db',
        'media/%2e%2e/y',
        SyncKeys.manifestPath,
      });
      final writes = backend.ops.where(
        (o) =>
            (o.startsWith('delete ') || o.startsWith('write ')) &&
            !o.endsWith(SyncKeys.lockPath),
      );
      expect(writes.take(2), [
        'delete ${SyncKeys.manifestPath}',
        'delete ${SyncKeys.keysPath}',
      ]);
      expect(writes.last, 'write ${SyncKeys.manifestPath}');
    });

    test('补种失败挂冲突标记，自动同步不会用旧密钥重铺空云端', () async {
      final backend =
          FakeRemoteBackend(
              objects: {
                'diary/a.json': Uint8List.fromList([1]),
              },
            )
            ..beforeOp = (op, key) {
              if (op == 'write' && key == SyncKeys.manifestPath) {
                throw const SyncException('offline');
              }
            };
      await SyncKeyManager.storeDek(SyncKeyManager.generateDek());

      await expectLater(
        RemoteWipe.run(backend, passphrase: null),
        throwsA(isA<SyncException>()),
      );
      expect(SyncKeyManager.hasKeyConflict('webdav'), isTrue);
    });

    test('删除失败重试一次，仍失败只计数，补种照常', () async {
      final backend = FakeRemoteBackend(
        objects: {
          SyncKeys.manifestPath: Uint8List.fromList([1]),
          'diary/a.json': Uint8List.fromList([1]),
          'diary/b.json': Uint8List.fromList([1]),
          'diary/c.json': Uint8List.fromList([1]),
        },
      );
      var flaky = 0;
      backend.beforeOp = (op, key) {
        if (op != 'delete') return;
        if (key == 'diary/a.json') throw const SyncException('denied');
        if (key == 'diary/c.json' && flaky++ == 0) {
          throw const SyncException('timeout');
        }
      };
      final report = await RemoteWipe.run(backend, passphrase: null);
      expect(report.failed, 1);
      expect(report.deleted, 4);
      expect(backend.objects.keys, {'diary/a.json', SyncKeys.manifestPath});
    });
  });
}
