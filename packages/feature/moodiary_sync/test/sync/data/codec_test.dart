import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/sync.dart';

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
}
