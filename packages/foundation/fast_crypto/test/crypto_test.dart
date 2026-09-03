import 'dart:io';

import 'package:fast_crypto/fast_crypto.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibrary;
import 'package:flutter_test/flutter_test.dart';

/// `flutter test` 会为宿主构建 hook，产物落在 `build/native_assets/<os>/`；FRB 默认去
/// rust/target/release/ 找，那份要么没有要么陈旧，所以显式指过去。
String _hostLibrary() {
  final (dir, file) = switch (Platform.operatingSystem) {
    'macos' => ('macos', 'libfastcrypto.dylib'),
    'linux' => ('linux', 'libfastcrypto.so'),
    'windows' => ('windows', 'fastcrypto.dll'),
    final os => throw UnsupportedError(os),
  };
  return 'build/native_assets/$dir/$file';
}

void main() {
  setUpAll(
    () => FastCryptoLib.init(
      externalLibrary: ExternalLibrary.open(_hostLibrary()),
    ),
  );

  // 测试里把 Argon2 成本压到最低：默认 64 MiB / 3 轮是给真实口令用的。盐至少 8 字节。
  Future<List<int>> key() => Aes.deriveKey(
    salt: 'salt-salt',
    userKey: 'pw',
    mCostKib: 8,
    tCost: 1,
    pCost: 1,
  );

  test('派生 32 字节密钥且可复现', () async {
    final a = await key();
    final b = await key();
    expect(a, hasLength(32));
    expect(a, b);
  });

  test('AES-GCM 往返', () async {
    final k = await key();
    final cipher = await Aes.encrypt(key: k, data: [1, 2, 3, 4]);
    expect(cipher.length, greaterThan(4));
    expect(await Aes.decrypt(key: k, encryptedData: cipher), [1, 2, 3, 4]);
  });

  test('错密钥以 FastCryptoException 收场，不崩', () async {
    final k = await key();
    final cipher = await Aes.encrypt(key: k, data: [9]);
    final wrong = List<int>.filled(32, 7);
    expect(
      () => Aes.decrypt(key: wrong, encryptedData: cipher),
      throwsA(isA<FastCryptoException>()),
    );
  });

  test('整文件加解密带魔数前缀', () async {
    final k = await key();
    final dir = await Directory.systemTemp.createTemp('fast_crypto');
    addTearDown(() => dir.delete(recursive: true));
    final plain = File('${dir.path}/p')..writeAsBytesSync([5, 6, 7]);
    final enc = '${dir.path}/e';
    final dec = '${dir.path}/d';
    await Aes.encryptFile(
      key: k,
      inPath: plain.path,
      outPath: enc,
      prefix: [0x4d, 0x44],
    );
    expect(File(enc).readAsBytesSync().sublist(0, 2), [0x4d, 0x44]);
    await Aes.decryptFile(key: k, inPath: enc, outPath: dec, skipPrefix: 2);
    expect(File(dec).readAsBytesSync(), [5, 6, 7]);
  });

  test('Argon2id hash / verify', () async {
    final hash = await Argon2.hash(password: '1234');
    expect(hash, startsWith(r'$argon2id$'));
    expect(await Argon2.verify(hash: hash, password: '1234'), isTrue);
    expect(await Argon2.verify(hash: hash, password: '4321'), isFalse);
  });
}
