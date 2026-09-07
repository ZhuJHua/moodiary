import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:fast_crypto/fast_crypto.dart' as crypto;
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_key_manager.dart';

class SyncCipher {
  static const String magic = 'MD-ENC-V1\n';

  final List<int>? aesKey;

  const SyncCipher.withKey(this.aesKey);

  static const SyncCipher plaintext = .withKey(null);

  static Future<SyncCipher> current() => SyncKeyManager.currentCipher();

  bool get encrypted => aesKey != null;

  static const int isolateThresholdBytes = 64 * 1024;

  Future<Uint8List> encode(Object value) async {
    final plain = await _encodeJson(value);
    if (!encrypted) return plain;
    return _framed(await _encrypt(plain));
  }

  Future<dynamic> decode(Uint8List bytes) async {
    final plain = await _maybeDecrypt(bytes);
    try {
      if (plain.length < isolateThresholdBytes) {
        return jsonDecode(utf8.decode(plain));
      }
      return await Isolate.run(() => jsonDecode(utf8.decode(plain)));
    } catch (e) {
      throw SyncException(l10n.sync.errBackupParse(error: '$e'));
    }
  }

  static Future<Uint8List> _encodeJson(Object value) async {
    final entries = value is Map ? value['entries'] : null;
    if (entries is Map && entries.length > 512) {
      return Isolate.run(() => utf8.encode(jsonEncode(value)));
    }
    return utf8.encode(jsonEncode(value));
  }

  Future<Uint8List> encryptBytes(Uint8List bytes) async {
    if (!encrypted) return bytes;
    return _framed(await _encrypt(bytes));
  }

  Future<Uint8List> decryptBytes(Uint8List bytes) async => _maybeDecrypt(bytes);

  Future<void> encryptFileTo(String srcPath, String dstPath) async {
    if (!encrypted) {
      await File(srcPath).copy(dstPath);
      return;
    }
    await crypto.Aes.encryptFile(
      key: aesKey!,
      inPath: srcPath,
      outPath: dstPath,
      prefix: utf8.encode(magic),
    );
  }

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
      await crypto.Aes.decryptFile(
        key: aesKey!,
        inPath: srcPath,
        outPath: dstPath,
        skipPrefix: magicBytes.length,
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

  static Uint8List _framed(Uint8List cipher) {
    final magicBytes = utf8.encode(magic);
    final out = Uint8List(magicBytes.length + cipher.length);
    out.setRange(0, magicBytes.length, magicBytes);
    out.setRange(magicBytes.length, out.length, cipher);
    return out;
  }

  Future<Uint8List> _encrypt(List<int> plain) =>
      crypto.Aes.encrypt(key: aesKey!, data: plain);

  Future<Uint8List> _maybeDecrypt(Uint8List bytes) async {
    if (!SyncCipher.isCipherText(bytes)) return bytes;
    if (!encrypted) {
      throw SyncException(l10n.sync.errNoUserKey);
    }
    try {
      final magicLen = utf8.encode(magic).length;
      return await crypto.Aes.decrypt(
        key: aesKey!,
        encryptedData: Uint8List.sublistView(bytes, magicLen),
      );
    } catch (_) {
      throw SyncException(l10n.sync.errDecryptFailed);
    }
  }
}
