import 'dart:convert';
import 'dart:typed_data';

import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_sync/src/data/sync.dart';

class SyncKeyfile {
  static const int currentVersion = 1;

  final int version;

  final int kdfMemoryKiB;
  final int kdfIterations;
  final int kdfParallelism;

  final String saltB64;

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
        l10n.sync.errKeyfileVersion(
          version: version,
          supported: currentVersion,
        ),
      );
    }
    final kdf = json['kdf'];
    final salt = json['salt'];
    final wrapped = json['wrapped'];
    if (kdf is! Map || salt is! String || wrapped is! String) {
      throw SyncException(l10n.sync.errKeyfileFields);
    }
    final m = kdf['mKiB'];
    final t = kdf['t'];
    final p = kdf['p'];
    if (m is! int || t is! int || p is! int) {
      throw SyncException(l10n.sync.errKeyfileKdfMissing);
    }
    // keys.json 为不可信输入，需限制 KDF 参数范围防止 OOM
    if (m < 8 * p || m > 256 * 1024 || t < 1 || t > 16 || p < 1 || p > 8) {
      throw SyncException(l10n.sync.errKeyfileKdfRange);
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
      throw SyncException(l10n.sync.errKeyfileParse(error: '$e'));
    }
    if (decoded is! Map<String, dynamic>) {
      throw SyncException(l10n.sync.errKeyfileCorrupt);
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
