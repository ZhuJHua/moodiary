import 'dart:convert';
import 'dart:typed_data';

import 'package:moodiary_rust/moodiary_rust.dart' as rust;
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_key_manager.dart';

/// 同步层字节编/解码器。持有原始 AES-256 key（数据密钥 DEK）直接加解密——
/// 密钥的派生 / 包装 / 存取全部在 [SyncKeyManager]（信封加密：随机 DEK 加密
/// 数据，用户密码只用来包 DEK）。格式 `MD-ENC-V1\n` magic 头 + AES-256-GCM；
/// 密钥正确性的唯一可信源 = AES-GCM auth tag，密钥错则解密失败抛 [SyncException]。
/// 不可变实例，构造时绑定一个 key（CloudReCipher 显式构造旧/新两个）。
class SyncCipher {
  static const String magic = 'MD-ENC-V1\n';

  /// 原始 32 字节 AES-256 key；`null` = 明文模式。
  final List<int>? aesKey;

  const SyncCipher.withKey(this.aesKey);

  static const SyncCipher plaintext = SyncCipher.withKey(null);

  /// 当前设备的 cipher：本机 SecureKV 里的 DEK，未配置即明文模式。
  static Future<SyncCipher> current() => SyncKeyManager.currentCipher();

  bool get encrypted => aesKey != null;

  Future<Uint8List> encode(Object value) async {
    final plain = utf8.encode(jsonEncode(value));
    if (!encrypted) return Uint8List.fromList(plain);
    return Uint8List.fromList([
      ...utf8.encode(magic),
      ...await _encrypt(plain),
    ]);
  }

  /// 自动按 magic 头识别加密；密文但本 cipher 未配密钥 → 抛 [SyncException]。
  Future<dynamic> decode(Uint8List bytes) async {
    final plain = await _maybeDecrypt(bytes);
    try {
      return jsonDecode(utf8.decode(plain));
    } catch (e) {
      throw SyncException('备份文件解析失败：$e');
    }
  }

  /// 原始字节加密（媒体文件）。
  Future<Uint8List> encryptBytes(Uint8List bytes) async {
    if (!encrypted) return bytes;
    return Uint8List.fromList([
      ...utf8.encode(magic),
      ...await _encrypt(bytes),
    ]);
  }

  Future<Uint8List> decryptBytes(Uint8List bytes) async => _maybeDecrypt(bytes);

  static bool isCipherText(Uint8List bytes) {
    final magicBytes = utf8.encode(magic);
    if (bytes.length <= magicBytes.length) return false;
    for (var i = 0; i < magicBytes.length; i++) {
      if (bytes[i] != magicBytes[i]) return false;
    }
    return true;
  }

  Future<Uint8List> _encrypt(List<int> plain) async {
    final cipher = await rust.Aes.encrypt(key: aesKey!, data: plain);
    return Uint8List.fromList(cipher);
  }

  Future<Uint8List> _maybeDecrypt(Uint8List bytes) async {
    if (!SyncCipher.isCipherText(bytes)) return bytes;
    if (!encrypted) {
      throw const SyncException('远端文件已加密，但当前未配置用户密钥');
    }
    try {
      final magicLen = utf8.encode(magic).length;
      return Uint8List.fromList(
        await rust.Aes.decrypt(
          key: aesKey!,
          encryptedData: bytes.sublist(magicLen),
        ),
      );
    } catch (_) {
      throw const SyncException('远端文件解密失败：用户密钥可能不匹配');
    }
  }
}
