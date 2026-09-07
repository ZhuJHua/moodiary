import 'dart:typed_data';

import 'package:flutter_rust_bridge/flutter_rust_bridge.dart'
    show AnyhowException;

import 'runtime.dart';
import 'rust/api/crypto.dart' as api;

class FastCryptoException implements Exception {
  const FastCryptoException(this.message);

  final String message;

  @override
  String toString() => 'FastCryptoException: $message';
}

Future<T> _call<T>(Future<T> Function() body) async {
  await FastCrypto.ensureInitialized();
  try {
    return await body();
  } on AnyhowException catch (e) {
    throw FastCryptoException(e.message);
  }
}

abstract final class Aes {
  static Future<Uint8List> deriveKey({
    required String salt,
    required String userKey,
    int? mCostKib,
    int? tCost,
    int? pCost,
  }) => _call(
    () => api.aesDeriveKey(
      salt: salt,
      userKey: userKey,
      mCostKib: mCostKib,
      tCost: tCost,
      pCost: pCost,
    ),
  );

  static Future<Uint8List> encrypt({
    required List<int> key,
    required List<int> data,
  }) => _call(() => api.aesEncrypt(key: _bytes(key), data: _bytes(data)));

  static Future<Uint8List> decrypt({
    required List<int> key,
    required List<int> encryptedData,
  }) => _call(
    () =>
        api.aesDecrypt(key: _bytes(key), encryptedData: _bytes(encryptedData)),
  );

  static Future<void> encryptFile({
    required List<int> key,
    required String inPath,
    required String outPath,
    required List<int> prefix,
  }) => _call(
    () => api.aesEncryptFile(
      key: _bytes(key),
      inPath: inPath,
      outPath: outPath,
      prefix: _bytes(prefix),
    ),
  );

  static Future<void> decryptFile({
    required List<int> key,
    required String inPath,
    required String outPath,
    required int skipPrefix,
  }) => _call(
    () => api.aesDecryptFile(
      key: _bytes(key),
      inPath: inPath,
      outPath: outPath,
      skipPrefix: skipPrefix,
    ),
  );
}

abstract final class Argon2 {
  static Future<String> hash({required String password}) =>
      _call(() => api.argon2Hash(password: password));

  static Future<bool> verify({
    required String hash,
    required String password,
  }) => _call(() => api.argon2Verify(hash: hash, password: password));
}

Uint8List _bytes(List<int> v) => v is Uint8List ? v : Uint8List.fromList(v);
