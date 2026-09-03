import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'ffi.dart' as c;

/// 原生侧报上来的错误（含密钥不对、文件读不到、参数非法）。
class FastCryptoException implements Exception {
  const FastCryptoException(this.message);

  final String message;

  @override
  String toString() => 'FastCryptoException: $message';
}

/// 一次调用里所有拷进 C 堆的入参，`free` 一并归还。
final class _Args {
  final _owned = <Pointer<Uint8>>[];

  (Pointer<Uint8>, int) bytes(List<int> data) {
    final ptr = calloc<Uint8>(data.isEmpty ? 1 : data.length);
    ptr.asTypedList(data.length).setAll(0, data);
    _owned.add(ptr);
    return (ptr, data.length);
  }

  (Pointer<Uint8>, int) text(String value) => bytes(utf8.encode(value));

  void free() {
    for (final ptr in _owned) {
      calloc.free(ptr);
    }
  }
}

/// 调一个 C 入口：出参先拷成 Dart 内存再归还 Rust 那份；非 0 返回码把载荷当错误信息抛。
Uint8List _call(int Function(_Args args, Pointer<c.FfiBuf> out) body) {
  final args = _Args();
  final out = calloc<c.FfiBuf>();
  try {
    final code = body(args, out);
    final buf = out.ref;
    final payload = Uint8List.fromList(buf.ptr.asTypedList(buf.len));
    c.fastcryptoBufFree(buf.ptr, buf.len, buf.cap);
    if (code != 0) {
      throw FastCryptoException(utf8.decode(payload, allowMalformed: true));
    }
    return payload;
  } finally {
    calloc.free(out);
    args.free();
  }
}

/// AES-256-GCM。全部跑在 `Isolate.run` 里：Argon2 派生与整文件加解密都是几十毫秒起的活。
abstract final class Aes {
  /// Argon2id 派生 32 字节密钥。成本参数不传用原生侧默认值（64 MiB / 3 / 4）。
  static Future<Uint8List> deriveKey({
    required String salt,
    required String userKey,
    int? mCostKib,
    int? tCost,
    int? pCost,
  }) => Isolate.run(
    () => _call((a, out) {
      final (s, sl) = a.text(salt);
      final (k, kl) = a.text(userKey);
      return c.fastcryptoAesDeriveKey(
        s,
        sl,
        k,
        kl,
        mCostKib ?? 0,
        tCost ?? 0,
        pCost ?? 0,
        out,
      );
    }),
  );

  static Future<Uint8List> encrypt({
    required List<int> key,
    required List<int> data,
  }) => Isolate.run(
    () => _call((a, out) {
      final (k, kl) = a.bytes(key);
      final (d, dl) = a.bytes(data);
      return c.fastcryptoAesEncrypt(k, kl, d, dl, out);
    }),
  );

  static Future<Uint8List> decrypt({
    required List<int> key,
    required List<int> encryptedData,
  }) => Isolate.run(
    () => _call((a, out) {
      final (k, kl) = a.bytes(key);
      final (d, dl) = a.bytes(encryptedData);
      return c.fastcryptoAesDecrypt(k, kl, d, dl, out);
    }),
  );

  /// 整文件加密，产物以 [prefix]（魔数）开头。
  static Future<void> encryptFile({
    required List<int> key,
    required String inPath,
    required String outPath,
    required List<int> prefix,
  }) => Isolate.run(
    () => _call((a, out) {
      final (k, kl) = a.bytes(key);
      final (i, il) = a.text(inPath);
      final (o, ol) = a.text(outPath);
      final (p, pl) = a.bytes(prefix);
      return c.fastcryptoAesEncryptFile(k, kl, i, il, o, ol, p, pl, out);
    }),
  );

  /// 整文件解密，跳过开头 [skipPrefix] 个字节的魔数。
  static Future<void> decryptFile({
    required List<int> key,
    required String inPath,
    required String outPath,
    required int skipPrefix,
  }) => Isolate.run(
    () => _call((a, out) {
      final (k, kl) = a.bytes(key);
      final (i, il) = a.text(inPath);
      final (o, ol) = a.text(outPath);
      return c.fastcryptoAesDecryptFile(k, kl, i, il, o, ol, skipPrefix, out);
    }),
  );
}

/// Argon2id 密码哈希（PHC 串）。
abstract final class Argon2 {
  static Future<String> hash({required String password}) => Isolate.run(
    () => utf8.decode(
      _call((a, out) {
        final (p, pl) = a.text(password);
        return c.fastcryptoArgon2Hash(p, pl, out);
      }),
    ),
  );

  static Future<bool> verify({
    required String hash,
    required String password,
  }) => Isolate.run(
    () =>
        _call((a, out) {
          final (h, hl) = a.text(hash);
          final (p, pl) = a.text(password);
          return c.fastcryptoArgon2Verify(h, hl, p, pl, out);
        }).single ==
        1,
  );
}
