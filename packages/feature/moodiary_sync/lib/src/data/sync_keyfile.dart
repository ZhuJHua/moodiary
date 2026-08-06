import 'dart:convert';
import 'dart:typed_data';

import 'package:moodiary_sync/src/data/sync.dart';

/// 远端 `keys.json`（明文 JSON）—— 信封加密的「信封」：
/// 数据由随机 DEK 做 AES-256-GCM；用户密码 + [saltB64] 经 Argon2id 派生 KEK，
/// KEK 只用来包 [wrappedDekB64] 里的 DEK。明文存放不泄密：盐本就无需保密，
/// 密文没有密码解不开；云服务商可见的信息与数据对象一致。
///
/// 收益（相对密码直接派生数据密钥）：盐随机（废掉全用户共享彩虹表）、改密码 =
/// 重写本文件单对象原子完成（数据零重写）、KDF 参数随文件可升级。
class SyncKeyfile {
  static const int currentVersion = 1;

  final int version;

  /// Argon2id 参数（随文件存储，未来可升级强度不破坏旧数据）。
  final int kdfMemoryKiB;
  final int kdfIterations;
  final int kdfParallelism;

  /// 随机盐（base64，派生 KEK 时以该 base64 字符串的字节作为盐）。
  final String saltB64;

  /// AES-GCM(KEK, DEK) 的 base64（12B nonce + 密文 + 16B tag，与对象加密同封装）。
  final String wrappedDekB64;

  const SyncKeyfile({
    this.version = currentVersion,
    required this.kdfMemoryKiB,
    required this.kdfIterations,
    required this.kdfParallelism,
    required this.saltB64,
    required this.wrappedDekB64,
  });

  factory SyncKeyfile.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    if (version is! int || version > currentVersion) {
      throw SyncException(
        '远端密钥文件版本不兼容（v$version，本机支持 ≤ v$currentVersion），请升级客户端',
      );
    }
    final kdf = json['kdf'];
    final salt = json['salt'];
    final wrapped = json['wrapped'];
    if (kdf is! Map || salt is! String || wrapped is! String) {
      throw const SyncException('远端密钥文件已损坏（字段缺失）');
    }
    final m = kdf['mKiB'];
    final t = kdf['t'];
    final p = kdf['p'];
    if (m is! int || t is! int || p is! int) {
      throw const SyncException('远端密钥文件已损坏（KDF 参数缺失）');
    }
    // keys.json 是不可信输入：不设上限的话，恶意文件可用超大 mKiB 让每次解锁
    // 尝试直接 OOM（Argon2 按 mKiB 分配内存）。上限取移动端可承受的宽裕值。
    if (m < 8 * p || m > 256 * 1024 || t < 1 || t > 16 || p < 1 || p > 8) {
      throw const SyncException('远端密钥文件的 KDF 参数超出允许范围');
    }
    return SyncKeyfile(
      version: version,
      kdfMemoryKiB: m,
      kdfIterations: t,
      kdfParallelism: p,
      saltB64: salt,
      wrappedDekB64: wrapped,
    );
  }

  static SyncKeyfile fromBytes(Uint8List bytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (e) {
      throw SyncException('远端密钥文件解析失败：$e');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const SyncException('远端密钥文件已损坏（非 JSON 对象）');
    }
    return .fromJson(decoded);
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'kdf': {
      'alg': 'argon2id',
      'mKiB': kdfMemoryKiB,
      't': kdfIterations,
      'p': kdfParallelism,
    },
    'salt': saltB64,
    'wrapped': wrappedDekB64,
  };

  Uint8List toBytes() => .fromList(utf8.encode(jsonEncode(toJson())));
}
