import 'dart:convert';
import 'dart:typed_data';

import 'package:moodiary/src/rust/api/aes.dart';

class AesUtil {
  /// 生成密钥
  static Future<Uint8List> deriveKey({
    required String salt,
    required String userKey,
  }) async {
    return await AesEncryption.deriveKey(salt: salt, userKey: userKey);
  }

  /// 加密数据
  static Future<Uint8List> encrypt({
    required Uint8List key,
    required String data,
  }) async {
    final keyBytes = key;
    final dataBytes = utf8.encode(data);
    final encrypted =
        await AesEncryption.encrypt(key: keyBytes, data: dataBytes);

    return encrypted;
  }

  /// 解密数据
  static Future<String> decrypt({
    required Uint8List key,
    required Uint8List encryptedData,
  }) async {
    final keyBytes = key;
    final encryptedBytes = encryptedData;
    final decrypted = await AesEncryption.decrypt(
        key: keyBytes, encryptedData: encryptedBytes);
    return utf8.decode(decrypted);
  }

}
