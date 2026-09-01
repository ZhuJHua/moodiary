import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_key_manager.dart';
import 'package:moodiary_sync/src/data/sync_keyfile.dart';

import '../sync_test_harness.dart';

/// 纯 Dart 假原语（宿主测试无 Rust FFI）：
/// - deriveKey：把 (salt, passphrase, 参数) 折叠成确定性的 32 字节；
/// - AEAD：`[checksum(key)] + data ^ key`，解密校验 checksum 模拟 GCM tag 失败。
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

    test('bytes 往返', () {
      final restored = SyncKeyfile.fromBytes(keyfile.toBytes());
      expect(restored.wrappedDekB64, keyfile.wrappedDekB64);
    });

    test('更高版本拒绝（防静默丢字段）', () {
      final json = keyfile.toJson()..['version'] = 99;
      expect(() => SyncKeyfile.fromJson(json), throwsA(isA<SyncException>()));
    });

    test('KDF 参数超限拒绝（keys.json 是不可信输入，防内存炸弹 DoS）', () {
      final json = keyfile.toJson();
      (json['kdf'] as Map)['mKiB'] = 4 * 1024 * 1024; // 4 GiB
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
      // 非 pending：零操作。
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

  // 远端唯一的信封一旦被换掉，用旧 DEK 加密的日记与媒体就永久解不开。这组用例钉住
  // 「写之前必须先证明本机 DEK 就是远端那把」。
  //
  // 「本机有 DEK 且解得开远端密文 manifest」那一支落在 Rust AES-GCM 上，宿主测试
  // 跑不了（同 codec_test 的限制），故只覆盖不需要真解密的分支。
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
      // 远端信封原封不动。
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

  group('verifyPassphrase', () {
    test('远端 keyfile 优先；解包 DEK 与本机一致才通过', () async {
      final dek = SyncKeyManager.generateDek();
      await SyncKeyManager.storeDek(dek);
      final kf = await SyncKeyManager.wrapDek(dek: dek, passphrase: 'p');
      final backend = FakeRemoteBackend();
      backend.objects[SyncKeys.keysPath] = kf.toBytes();

      expect(
        await SyncKeyManager.verifyPassphrase('p', backend: backend),
        isTrue,
      );
      expect(
        await SyncKeyManager.verifyPassphrase('wrong', backend: backend),
        isFalse,
      );
    });

    test('远端不可达回退本机缓存', () async {
      final dek = SyncKeyManager.generateDek();
      await SyncKeyManager.storeDek(dek);
      final kf = await SyncKeyManager.wrapDek(dek: dek, passphrase: 'p');
      SyncKeyManager.cacheKeyfile(kf);

      final backend = FakeRemoteBackend();
      backend.beforeOp = (op, key) => throw const SyncException('offline');

      expect(
        await SyncKeyManager.verifyPassphrase('p', backend: backend),
        isTrue,
      );
    });

    test('本机无 DEK / 无任何 keyfile → false', () async {
      expect(await SyncKeyManager.verifyPassphrase('p'), isFalse);
      await SyncKeyManager.storeDek(SyncKeyManager.generateDek());
      expect(await SyncKeyManager.verifyPassphrase('p'), isFalse);
    });

    test('keyfile 包的是别把 DEK → false（防串库）', () async {
      await SyncKeyManager.storeDek(SyncKeyManager.generateDek());
      final other = await SyncKeyManager.wrapDek(
        dek: SyncKeyManager.generateDek(),
        passphrase: 'p',
      );
      SyncKeyManager.cacheKeyfile(other);
      expect(await SyncKeyManager.verifyPassphrase('p'), isFalse);
    });
  });
}
