/// 局域网单向同步的协议常量与会话加密端口。
///
/// 安全模型（有意的取舍，非疏忽）：
/// - 会话密钥 = Argon2id(随机会话盐, 6 位 PIN)。盐每次接收会话随机生成、握手明文
///   下发 —— 杜绝对全部 10^6 个 PIN 的彩虹预计算，被动监听者离线穷举需对每个候选
///   PIN 跑一次 Argon2id（64 MiB 内存硬化）。
/// - 请求认证 = 把握手下发的 challenge 用会话密钥 AES-GCM 加密后随请求回传，接收方
///   解密比对。同一会话内可重放（LAN + 一次性 PIN + 会话即弃，接受）。
/// - 载荷：控制面（manifest / 报告）整体 AES-256-GCM；归档 zip 以密钥 hex 作条目
///   级 AES-256 密码（流式加解密，GB 级媒体不进内存）。
/// - 不做 PAKE：主动 MITM 与在线穷举在此威胁模型下不设防（归档的 lan-transfer
///   设计文档 §3 记录过 PAKE 路线，被明确放弃）。
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:moodiary_rust/moodiary_rust.dart' as rust;

const int lanDefaultPort = 6636;
const int lanProtoVersion = 1;
const String lanApiBase = '/moodiary/lan/v1';
const String lanHandshakePath = '$lanApiBase/handshake';
const String lanManifestPath = '$lanApiBase/manifest';
const String lanArchivePath = '$lanApiBase/archive';
const String lanAuthHeader = 'x-moodiary-auth';

/// 会话加密端口：生产走 Rust（Argon2id + AES-256-GCM），测试注入纯 Dart 假实现。
abstract interface class LanCrypto {
  Future<List<int>> deriveKey({required String salt, required String pin});

  Future<Uint8List> encrypt(List<int> key, List<int> plain);

  /// 解密失败（密钥不对 / 数据损坏）必须抛异常，认证逻辑依赖这一点。
  Future<Uint8List> decrypt(List<int> key, List<int> cipher);
}

class RustLanCrypto implements LanCrypto {
  const RustLanCrypto();

  @override
  Future<List<int>> deriveKey({required String salt, required String pin}) =>
      rust.Aes.deriveKey(salt: salt, userKey: pin);

  @override
  Future<Uint8List> encrypt(List<int> key, List<int> plain) async =>
      Uint8List.fromList(await rust.Aes.encrypt(key: key, data: plain));

  @override
  Future<Uint8List> decrypt(List<int> key, List<int> cipher) async =>
      Uint8List.fromList(
        await rust.Aes.decrypt(key: key, encryptedData: cipher),
      );
}

final Random _secureRandom = Random.secure();

String lanGeneratePin() =>
    (_secureRandom.nextInt(900000) + 100000).toString();

String lanRandomHex(int byteCount) => bytesToHex([
  for (var i = 0; i < byteCount; i++) _secureRandom.nextInt(256),
]);

String bytesToHex(List<int> bytes) => [
  for (final b in bytes) b.toRadixString(16).padLeft(2, '0'),
].join();

List<int> hexToBytes(String hex) => [
  for (var i = 0; i + 1 < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
];

/// 归档 zip 的条目密码：会话密钥的 hex（256 bit 熵，zip 内置 PBKDF2 不构成短板）。
String lanZipPassword(List<int> key) => bytesToHex(key);
