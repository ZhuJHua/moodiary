import 'dart:convert';
import 'dart:typed_data';

import 'package:dartx/dartx.dart';
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
    final encrypted = await AesEncryption.encrypt(
      key: keyBytes,
      data: dataBytes,
    );

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
      key: keyBytes,
      encryptedData: encryptedBytes,
    );
    return utf8.decode(decrypted);
  }

  /// 基于时间窗口加密
  static Future<Uint8List> encryptWithTimeWindow({
    required String data,
    required Duration validDuration,
  }) async {
    final timeSlot = _currentTimeSlot(validDuration);
    final dynamicKey = timeSlot.toString().md5;
    final salt = _dailySalt();

    final aesKey = await deriveKey(salt: salt, userKey: dynamicKey);
    return await encrypt(key: aesKey, data: data);
  }

  /// 基于时间窗口解密
  static Future<String?> decryptWithTimeWindow({
    required Uint8List encryptedData,
    required Duration validDuration,
    int toleranceSlots = 1,
  }) async {
    final currentSlot = _currentTimeSlot(validDuration);
    final salt = _dailySalt();

    for (int offset = 0; offset <= toleranceSlots; offset++) {
      for (final slot in [currentSlot - offset, currentSlot + offset]) {
        final dynamicKey = slot.toString().md5;
        final aesKey = await deriveKey(salt: salt, userKey: dynamicKey);
        try {
          final result = await decrypt(
            key: aesKey,
            encryptedData: encryptedData,
          );
          return result;
        } catch (_) {
          continue;
        }
      }
    }

    return null;
  }

  static int _currentTimeSlot(Duration duration) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return now ~/ duration.inMilliseconds;
  }

  static String _dailySalt() {
    final date = DateTime.now();
    return '${date.year}-${date.month}-${date.day}'.md5;
  }
}
