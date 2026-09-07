library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:fast_crypto/fast_crypto.dart';
import 'package:moodiary_platform/moodiary_platform.dart';

const int lanDefaultPort = 6636;

const int lanProtoVersion = 3;
const String lanApiBase = '/moodiary/lan/v1';
const String lanHandshakePath = '$lanApiBase/handshake';
const String lanManifestPath = '$lanApiBase/manifest';
const String lanArchivePath = '$lanApiBase/archive';
const String lanAuthHeader = 'x-moodiary-auth';

const String lanProtoHeader = 'x-moodiary-proto';

const String lanVersionHeader = 'x-moodiary-version';

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

String lanDisplayVersion(String? wire) {
  if (wire == null || wire.isEmpty) return 'unknown';
  final plus = wire.indexOf('+');
  if (plus <= 0) return wire;
  return '${wire.substring(0, plus)} (${wire.substring(plus + 1)})';
}

Map<String, String> lanTxtRecord(String version) => {
  'proto': '$lanProtoVersion',
  'ver': version,
};

abstract interface class LanCrypto {
  Future<List<int>> deriveKey({required String salt, required String pin});

  Future<Uint8List> encrypt(List<int> key, List<int> plain);

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

String lanZipPassword(List<int> key) => bytesToHex(key);

const int lanNonceBytes = 16;

const int lanMaxAuthFailures = 5;

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
