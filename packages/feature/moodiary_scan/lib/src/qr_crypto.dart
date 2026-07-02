import 'dart:typed_data';

import 'package:dartx/dartx.dart';
import 'package:moodiary_rust/moodiary_rust.dart' as rust;

/// 基于时间窗口的对称加密（二维码专用）：过期后无法重放。
/// slot = `floor(nowMs / validDuration)`；key 由 slot 的 MD5（userKey）+ 当日 MD5（salt）派生；
/// 解密尝试当前 slot 及 ±N 邻接 slot 以容忍时钟漂移。
class QrCrypto {
  const QrCrypto._();

  static Future<Uint8List> encryptWithTimeWindow({
    required String data,
    required Duration validDuration,
  }) async {
    final slot = _currentTimeSlot(validDuration);
    final aesKey = await rust.Aes.deriveKey(
      salt: _dailySalt(),
      userKey: slot.toString().md5,
    );
    return rust.Aes.encrypt(key: aesKey, data: data.codeUnits);
  }

  /// 失败（过期 / 篡改 / 超出 [toleranceSlots] 容差）返回 `null`。
  static Future<String?> decryptWithTimeWindow({
    required Uint8List encryptedData,
    required Duration validDuration,
    int toleranceSlots = 1,
  }) async {
    final currentSlot = _currentTimeSlot(validDuration);
    final salt = _dailySalt();
    for (var offset = 0; offset <= toleranceSlots; offset++) {
      for (final slot in {currentSlot - offset, currentSlot + offset}) {
        final aesKey = await rust.Aes.deriveKey(
          salt: salt,
          userKey: slot.toString().md5,
        );
        try {
          final bytes = await rust.Aes.decrypt(
            key: aesKey,
            encryptedData: encryptedData,
          );
          return String.fromCharCodes(bytes);
        } catch (_) {
          continue;
        }
      }
    }
    return null;
  }

  static int _currentTimeSlot(Duration duration) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return nowMs ~/ duration.inMilliseconds;
  }

  static String _dailySalt() {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}'.md5;
  }
}
