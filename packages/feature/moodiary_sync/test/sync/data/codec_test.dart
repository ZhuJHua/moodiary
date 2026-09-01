import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:path/path.dart' as p;

void main() {
  // 仅覆盖明文路径与密文识别 —— 加密走 Rust AES-GCM，无法在 flutter test 中跑。
  group('SyncCipher plaintext', () {
    const cipher = SyncCipher.plaintext;

    test('encrypted flag follows the presence of a raw key', () {
      expect(const SyncCipher.withKey(null).encrypted, isFalse);
      expect(const SyncCipher.withKey([1, 2, 3]).encrypted, isTrue);
    });

    test('encode → decode round-trips a map and is bare utf8 json', () async {
      final bytes = await cipher.encode({'a': 1, 'b': 'x'});
      // 明文模式不加 magic 头。
      expect(SyncCipher.isCipherText(bytes), isFalse);
      expect(jsonDecode(utf8.decode(bytes)), {'a': 1, 'b': 'x'});

      final decoded = await cipher.decode(bytes);
      expect(decoded, {'a': 1, 'b': 'x'});
    });

    test(
      'encryptBytes / decryptBytes are identity in plaintext mode',
      () async {
        final data = Uint8List.fromList([1, 2, 3, 4]);
        expect(await cipher.encryptBytes(data), data);
        expect(await cipher.decryptBytes(data), data);
      },
    );

    test('decode of ciphertext without a key throws SyncException', () async {
      final ciphertext = Uint8List.fromList([
        ...utf8.encode(SyncCipher.magic),
        9,
        9,
        9,
      ]);
      expect(SyncCipher.isCipherText(ciphertext), isTrue);
      expect(cipher.decode(ciphertext), throwsA(isA<SyncException>()));
    });

    test('decode of invalid json throws SyncException', () async {
      final garbage = Uint8List.fromList(utf8.encode('{not json'));
      expect(cipher.decode(garbage), throwsA(isA<SyncException>()));
    });

    test('isCipherText needs the full magic header', () {
      expect(SyncCipher.isCipherText(.fromList([1, 2, 3])), isFalse);
      expect(
        SyncCipher.isCipherText(.fromList(utf8.encode('MD-ENC'))),
        isFalse,
      );
    });
  });

  // 文件版的加解密本体在 Rust（moodiary-crypto 那侧有格式互通测试），这里只覆盖
  // 不需要 FFI 的分支：明文直通与「密文但无密钥」。
  group('SyncCipher file path', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('codec-file-test');
    });

    tearDown(() => dir.delete(recursive: true));

    test('plaintext mode copies the file untouched both ways', () async {
      const cipher = SyncCipher.plaintext;
      final src = File(p.join(dir.path, 'src.bin'));
      final payload = Uint8List.fromList(List.generate(4096, (i) => i % 256));
      await src.writeAsBytes(payload);

      final enc = p.join(dir.path, 'enc.bin');
      await cipher.encryptFileTo(src.path, enc);
      expect(await File(enc).readAsBytes(), payload);

      final dec = p.join(dir.path, 'dec.bin');
      await cipher.decryptFileTo(enc, dec);
      expect(await File(dec).readAsBytes(), payload);
    });

    test('ciphertext without a key is rejected, not silently copied', () async {
      const cipher = SyncCipher.plaintext;
      final enc = File(p.join(dir.path, 'enc.bin'));
      await enc.writeAsBytes([...utf8.encode(SyncCipher.magic), 1, 2, 3, 4]);

      await expectLater(
        cipher.decryptFileTo(enc.path, p.join(dir.path, 'out.bin')),
        throwsA(isA<SyncException>()),
      );
      expect(File(p.join(dir.path, 'out.bin')).existsSync(), isFalse);
    });
  });
}
