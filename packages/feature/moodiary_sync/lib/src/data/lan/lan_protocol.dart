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
/// - 载荷：控制面（manifest / 报告）整体 AES-256-GCM；归档 zip 是明文容器，每个条目
///   的内容经 [lanArchiveCipher]（与云端同步同一套 magic 头 + AES-256-GCM 对象格式，
///   媒体整文件走原生加解密，不进 Dart 堆）。接收端 `requireEncrypted`：明文条目一律拒收。
/// - 不做 PAKE：主动 MITM 不设防（归档的 lan-transfer 设计文档 §3 记录过 PAKE 路线，
///   被明确放弃）。
///
/// **仍然存在的残余风险**：抓到一次会话流量的被动监听者可以离线穷举 PIN —— 令牌的
/// 明文（nonce ‖ path）里 path 是已知的，逐个候选 PIN 派生密钥试解即可验证。6 位
/// PIN = 10^6 个候选，每个要跑一次 Argon2id(64 MiB, t=3)，单核约 100 ms，多核工作站
/// 量级在小时级。这是低熵配对码 + 非 PAKE 的固有代价，只能靠提高 PIN 熵来抬高。
///
/// **版本门**：兼容性只看 [lanProtoVersion]，两端严格相等才通（握手由发送端比对，带令牌
/// 的请求由接收端比对 [lanProtoHeader]，mDNS TXT 里也广播一份供发送页预筛）。App 版本
/// 只进报错文案。**动了线上格式的任何一处 —— 端点、令牌、manifest 结构、归档条目封装、
/// 加密对象格式 —— 必须 bump**；`lan_protocol_test.dart` 把有常量可钉的那些钉成指纹，
/// 没常量可钉的（例如条目封装方式）只能靠这条规则。
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:fast_crypto/fast_crypto.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_sync/src/data/codec.dart';

const int lanDefaultPort = 6636;

/// 3：归档从 zip 条目级 AES 改为明文 zip + 条目走 [SyncCipher]（接收端拒收明文条目）。
const int lanProtoVersion = 3;
const String lanApiBase = '/moodiary/lan/v1';
const String lanHandshakePath = '$lanApiBase/handshake';
const String lanManifestPath = '$lanApiBase/manifest';
const String lanArchivePath = '$lanApiBase/archive';
const String lanAuthHeader = 'x-moodiary-auth';

/// 发送端每个请求都带：接收端据此拒绝协议不同的发送端（握手只能挡住会检查的发送端）。
const String lanProtoHeader = 'x-moodiary-proto';

/// 发送端 App 版本，只进接收端的报错文案。
const String lanVersionHeader = 'x-moodiary-version';

/// 本机 App 版本的线上形式 `2.8.1+101`。取不到（测试环境）给 `unknown`：它只进文案，
/// 不能因为它挡住同步。
Future<String> lanLocalAppVersion() async {
  try {
    final info = await AppInfo.getPackageInfo();
    return info.buildNumber.isEmpty
        ? info.version
        : '${info.version}+${info.buildNumber}';
  } catch (_) {
    return 'unknown';
  }
}

/// `2.8.1+101` → `2.8.1 (101)`。
String lanDisplayVersion(String? wire) {
  if (wire == null || wire.isEmpty) return 'unknown';
  final plus = wire.indexOf('+');
  if (plus <= 0) return wire;
  return '${wire.substring(0, plus)} (${wire.substring(plus + 1)})';
}

/// mDNS TXT 记录：发送页据此把协议不同的接收端置灰。
Map<String, String> lanTxtRecord(String version) => {
  'proto': '$lanProtoVersion',
  'ver': version,
};

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
      Aes.deriveKey(salt: salt, userKey: pin);

  @override
  Future<Uint8List> encrypt(List<int> key, List<int> plain) async =>
      .fromList(await Aes.encrypt(key: key, data: plain));

  @override
  Future<Uint8List> decrypt(List<int> key, List<int> cipher) async =>
      .fromList(await Aes.decrypt(key: key, encryptedData: cipher));
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

/// 归档条目的 cipher：会话密钥直接当 DEK。发送端只用它加密；接收端靠 `requireEncrypted`
/// 把「能解开」当作对端持有会话密钥的证明。
SyncCipher lanArchiveCipher(List<int> key) =>
    SyncCipher.withKey(key, requireEncrypted: true);

/// 令牌里 nonce 的字节数（定长前缀，其余是绑定的 path）。
const int lanNonceBytes = 16;

/// 认证连续失败多少次后锁死会话。合法用户输错 PIN 也走这里，故留几次余量。
const int lanMaxAuthFailures = 5;

/// 造一次性请求令牌。绑定 path 是为了让令牌不能挪用到别的端点上。
///
/// 不再额外绑定请求体：控制面响应本就整体 AES-GCM、归档条目逐个 AES-GCM，
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
