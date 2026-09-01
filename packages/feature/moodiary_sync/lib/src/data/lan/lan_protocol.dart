/// 局域网单向同步的协议常量与会话加密端口。
///
/// 安全模型（有意的取舍，非疏忽）：
/// - 会话密钥 = Argon2id(随机会话盐, 6 位 PIN)。盐每次接收会话随机生成、握手明文
///   下发 —— 杜绝对全部 10^6 个 PIN 的彩虹预计算，被动监听者离线穷举需对每个候选
///   PIN 跑一次 Argon2id（64 MiB 内存硬化）。
/// - 请求认证 = **一次性令牌**：AES-GCM(会话密钥, 随机 nonce ‖ 目标 path)。接收方
///   解密、比对 path、并记下 nonce —— 没有会话密钥造不出令牌，同一个令牌也用不了
///   第二次。（协议 1 回传的是握手下发的固定 challenge，同会话内可无限重放。）
/// - 在线穷举 = 认证连续失败 [lanMaxAuthFailures] 次即锁死本次会话，必须重开接收页
///   换新 PIN。
/// - 载荷：控制面（manifest / 报告）整体 AES-256-GCM；归档 zip 以密钥 hex 作条目
///   级 AES-256 密码（流式加解密，GB 级媒体不进内存）。
/// - 不做 PAKE：主动 MITM 不设防（归档的 lan-transfer 设计文档 §3 记录过 PAKE 路线，
///   被明确放弃）。
///
/// **仍然存在的残余风险**：抓到一次会话流量的被动监听者可以离线穷举 PIN —— 令牌的
/// 明文（nonce ‖ path）里 path 是已知的，逐个候选 PIN 派生密钥试解即可验证。6 位
/// PIN = 10^6 个候选，每个要跑一次 Argon2id(64 MiB, t=3)，单核约 100 ms，多核工作站
/// 量级在小时级。这是低熵配对码 + 非 PAKE 的固有代价，只能靠提高 PIN 熵来抬高。
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:moodiary_rust/foundation.dart' as rust;

const int lanDefaultPort = 6636;
const int lanProtoVersion = 2;
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
      .fromList(await rust.Aes.encrypt(key: key, data: plain));

  @override
  Future<Uint8List> decrypt(List<int> key, List<int> cipher) async =>
      .fromList(await rust.Aes.decrypt(key: key, encryptedData: cipher));
}

final Random _secureRandom = .secure();

String lanGeneratePin() => (_secureRandom.nextInt(900000) + 100000).toString();

String lanRandomHex(int byteCount) => bytesToHex([
  for (var i = 0; i < byteCount; i++) _secureRandom.nextInt(256),
]);

String bytesToHex(List<int> bytes) =>
    [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')].join();

List<int> hexToBytes(String hex) => [
  for (var i = 0; i + 1 < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
];

/// 归档 zip 的条目密码：会话密钥的 hex（256 bit 熵，zip 内置 PBKDF2 不构成短板）。
String lanZipPassword(List<int> key) => bytesToHex(key);

/// 令牌里 nonce 的字节数（定长前缀，其余是绑定的 path）。
const int lanNonceBytes = 16;

/// 认证连续失败多少次后锁死会话。合法用户输错 PIN 也走这里，故留几次余量。
const int lanMaxAuthFailures = 5;

/// 造一次性请求令牌。绑定 path 是为了让令牌不能挪用到别的端点上。
///
/// 不再额外绑定请求体：控制面响应本就整体 AES-GCM、归档 zip 逐条目 AES-256，
/// 两者都要会话密钥才造得出，令牌再压一层 body 摘要并不多挡什么，却要引进一个
/// 目前 Rust 门面没有导出的哈希原语。
Future<String> lanBuildAuthToken(
  LanCrypto crypto,
  List<int> key,
  String path,
) async => base64Encode(
  await crypto.encrypt(key, [
    ...hexToBytes(lanRandomHex(lanNonceBytes)),
    ...utf8.encode(path),
  ]),
);

/// 校验令牌，返回其中的 nonce（hex）供调用方查重；密钥不对 / path 不符 → null。
Future<String?> lanReadAuthToken(
  LanCrypto crypto,
  List<int> key,
  String header,
  String path,
) async {
  try {
    final plain = await crypto.decrypt(key, base64Decode(header));
    if (plain.length <= lanNonceBytes) return null;
    if (utf8.decode(plain.sublist(lanNonceBytes)) != path) return null;
    return bytesToHex(plain.sublist(0, lanNonceBytes));
  } catch (_) {
    return null;
  }
}
