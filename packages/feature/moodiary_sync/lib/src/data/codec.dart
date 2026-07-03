import 'dart:convert';
import 'dart:typed_data';

import 'package:moodiary_rust/moodiary_rust.dart' as rust;
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_sync/src/data/sync.dart';

/// 同步层字节编/解码器。用户密钥即加密开关：配了 [MoodiarySecureKVs.userKey]
/// → 加密，清空 → 明文。格式 `MD-ENC-V1\n` magic 头 + AES-256-GCM；
/// 密钥正确性的唯一可信源 = AES-GCM auth tag，密钥错则解密失败抛 [SyncException]。
/// 不可变实例，构造时绑定一个 key（CloudReCipher 显式构造旧/新两个）。
class SyncCipher {
  static const String magic = 'MD-ENC-V1\n';

  /// 固定盐值。Argon2id 要求 salt >= 8 字节，且多设备须派生同一 AES key，
  /// 故 salt 必须全用户确定、不暴露给配置。
  static const String salt = 'moodiary';

  /// userKey → 派生 key 的进程级缓存。用 Future 让派生期间并发请求复用同一 future。
  static final Map<String, Future<List<int>>> _keyCache = {};

  /// `null` / 空字符串 → 明文模式。
  final String? userKey;

  const SyncCipher(this.userKey);

  static Future<SyncCipher> current() async {
    final raw = await MoodiarySecureKVs.userKey.get();
    return SyncCipher((raw == null || raw.isEmpty) ? null : raw);
  }

  static const SyncCipher plaintext = SyncCipher(null);

  bool get encrypted => userKey != null && userKey!.isNotEmpty;

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

  /// 调用方须先确保 [encrypted] 为真。
  Future<List<int>> _aesKey() {
    return _keyCache.putIfAbsent(
      userKey!,
      () => rust.Aes.deriveKey(salt: salt, userKey: userKey!),
    );
  }

  Future<Uint8List> _encrypt(List<int> plain) async {
    final aesKey = await _aesKey();
    final cipher = await rust.Aes.encrypt(key: aesKey, data: plain);
    return Uint8List.fromList(cipher);
  }

  Future<Uint8List> _maybeDecrypt(Uint8List bytes) async {
    if (!SyncCipher.isCipherText(bytes)) return bytes;
    if (!encrypted) {
      throw const SyncException('远端文件已加密，但当前未配置用户密钥');
    }
    final aesKey = await _aesKey();
    try {
      final magicLen = utf8.encode(magic).length;
      return Uint8List.fromList(
        await rust.Aes.decrypt(
          key: aesKey,
          encryptedData: bytes.sublist(magicLen),
        ),
      );
    } catch (_) {
      throw const SyncException('远端文件解密失败：用户密钥可能不匹配');
    }
  }
}
