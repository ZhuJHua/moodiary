import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_core/moodiary_core.dart';
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
      await SyncKeyManager.cacheKeyfile(kf);
      expect(SyncKeyManager.cachedKeyfile()?.wrappedDekB64, kf.wrappedDekB64);

      await MoodiaryKVs.syncKeyfileCache.set('not-json');
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
      await SyncKeyManager.cacheKeyfile(kf);
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
      await SyncKeyManager.cacheKeyfile(kf);

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
      await SyncKeyManager.cacheKeyfile(other);
      expect(await SyncKeyManager.verifyPassphrase('p'), isFalse);
    });
  });
}
