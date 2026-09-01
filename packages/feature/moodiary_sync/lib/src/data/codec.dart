import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_rust/foundation.dart' as rust;
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

  static const SyncCipher plaintext = .withKey(null);

  /// 当前设备的 cipher：本机 SecureKV 里的 DEK，未配置即明文模式。
  static Future<SyncCipher> current() => SyncKeyManager.currentCipher();

  bool get encrypted => aesKey != null;

  Future<Uint8List> encode(Object value) async {
    final plain = utf8.encode(jsonEncode(value));
    if (!encrypted) return plain;
    return _framed(await _encrypt(plain));
  }

  /// 自动按 magic 头识别加密；密文但本 cipher 未配密钥 → 抛 [SyncException]。
  Future<dynamic> decode(Uint8List bytes) async {
    final plain = await _maybeDecrypt(bytes);
    try {
      return jsonDecode(utf8.decode(plain));
    } catch (e) {
      throw SyncException(l10n.sync.errBackupParse(error: '$e'));
    }
  }

  /// 原始字节加密（媒体文件）。
  Future<Uint8List> encryptBytes(Uint8List bytes) async {
    if (!encrypted) return bytes;
    return _framed(await _encrypt(bytes));
  }

  Future<Uint8List> decryptBytes(Uint8List bytes) async => _maybeDecrypt(bytes);

  /// [encryptBytes] 的文件版：明文与密文都不进 Dart 内存。明文模式退化为复制。
  Future<void> encryptFileTo(String srcPath, String dstPath) async {
    if (!encrypted) {
      await File(srcPath).copy(dstPath);
      return;
    }
    await rust.Aes.encryptFile(
      key: aesKey!,
      inPath: srcPath,
      outPath: dstPath,
      prefix: utf8.encode(magic),
    );
  }

  /// [decryptBytes] 的文件版，语义相同：按 magic 头识别，明文原样复制。
  Future<void> decryptFileTo(String srcPath, String dstPath) async {
    final magicBytes = utf8.encode(magic);
    final head = await _readHead(srcPath, magicBytes.length);
    if (!_startsWith(head, magicBytes)) {
      await File(srcPath).copy(dstPath);
      return;
    }
    if (!encrypted) {
      throw SyncException(l10n.sync.errNoUserKey);
    }
    try {
      await rust.Aes.decryptFile(
        key: aesKey!,
        inPath: srcPath,
        outPath: dstPath,
        skipPrefix: BigInt.from(magicBytes.length),
      );
    } catch (_) {
      throw SyncException(l10n.sync.errDecryptFailed);
    }
  }

  static Future<Uint8List> _readHead(String path, int length) async {
    final handle = await File(path).open();
    try {
      return await handle.read(length);
    } finally {
      await handle.close();
    }
  }

  static bool _startsWith(Uint8List bytes, Uint8List prefix) {
    if (bytes.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }

  static bool isCipherText(Uint8List bytes) {
    final magicBytes = utf8.encode(magic);
    if (bytes.length <= magicBytes.length) return false;
    for (var i = 0; i < magicBytes.length; i++) {
      if (bytes[i] != magicBytes[i]) return false;
    }
    return true;
  }

  /// 必须预分配 typed buffer：`[...a, ...b]` 的字面量上下文类型是 `List<int>`，会先
  /// 摊出一个每字节一个字长的装箱列表，媒体文件走这条 = OOM。
  static Uint8List _framed(Uint8List cipher) {
    final magicBytes = utf8.encode(magic);
    final out = Uint8List(magicBytes.length + cipher.length);
    out.setRange(0, magicBytes.length, magicBytes);
    out.setRange(magicBytes.length, out.length, cipher);
    return out;
  }

  Future<Uint8List> _encrypt(List<int> plain) =>
      rust.Aes.encrypt(key: aesKey!, data: plain);

  Future<Uint8List> _maybeDecrypt(Uint8List bytes) async {
    if (!SyncCipher.isCipherText(bytes)) return bytes;
    if (!encrypted) {
      throw SyncException(l10n.sync.errNoUserKey);
    }
    try {
      final magicLen = utf8.encode(magic).length;
      // 视图而非拷贝：FRB 的编码器直接把它 setRange 进 Rust 缓冲区。
      return await rust.Aes.decrypt(
        key: aesKey!,
        encryptedData: Uint8List.sublistView(bytes, magicLen),
      );
    } catch (_) {
      throw SyncException(l10n.sync.errDecryptFailed);
    }
  }
}
