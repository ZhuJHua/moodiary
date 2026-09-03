import 'dart:typed_data';

import 'package:flutter_rust_bridge/flutter_rust_bridge.dart'
    show AnyhowException;

import 'runtime.dart';
import 'rust/api/crypto.dart' as api;

/// 原生侧报上来的错误（含密钥不对、文件读不到、参数非法）。
class FastCryptoException implements Exception {
  const FastCryptoException(this.message);

  final String message;

  @override
  String toString() => 'FastCryptoException: $message';
}

/// 每次调用先保证库已装载；Rust 的 `Err` 统一转成 [FastCryptoException]。
Future<T> _call<T>(Future<T> Function() body) async {
  await FastCrypto.ensureInitialized();
  try {
    return await body();
  } on AnyhowException catch (e) {
    throw FastCryptoException(e.message);
  }
}

/// AES-256-GCM。全部跑在 FRB 线程池上。
abstract final class Aes {
  /// Argon2id 派生 32 字节密钥。成本参数不传用原生侧默认值（64 MiB / 3 / 4）。
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

  /// 整文件加密，产物以 [prefix]（魔数）开头。
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

  /// 整文件解密，跳过开头 [skipPrefix] 个字节的魔数。
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

/// Argon2id 密码哈希（PHC 串）。
abstract final class Argon2 {
  static Future<String> hash({required String password}) =>
      _call(() => api.argon2Hash(password: password));

  static Future<bool> verify({
    required String hash,
    required String password,
  }) => _call(() => api.argon2Verify(hash: hash, password: password));
}

/// FRB 的 `Vec<u8>` 参数是 `Uint8List`；视图能省拷贝就省。
Uint8List _bytes(List<int> v) => v is Uint8List ? v : Uint8List.fromList(v);
