import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;

class AESUtil {
  final encrypt.Key _key;
  final encrypt.IV _iv;

  // 初始化时设置密钥和初始化向量（IV）
  AESUtil(String key, String iv)
      : _key = encrypt.Key.fromUtf8(key.padRight(32, ' ')),
        // 32字节密钥
        _iv = encrypt.IV.fromUtf8(iv.padRight(16, ' ')); // 16字节IV

  // 加密数据
  String encryptData(String data) {
    final encrypter = encrypt.Encrypter(encrypt.AES(_key));
    final encrypted = encrypter.encrypt(data, iv: _iv);
    return encrypted.base64; // 返回加密后的数据
  }

  // 解密数据
  String decryptData(String encryptedData) {
    final encrypter = encrypt.Encrypter(encrypt.AES(_key));
    final decrypted = encrypter.decrypt64(encryptedData, iv: _iv);
    return decrypted; // 返回解密后的数据
  }
}
