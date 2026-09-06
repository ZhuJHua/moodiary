import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:fast_crypto/fast_crypto.dart' as crypto;
import 'package:flutter/foundation.dart' show listEquals, visibleForTesting;
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_keyfile.dart';

enum RemoteKeyfileCheck {
  safe,

  conflict,

  unknown,
}

typedef DeriveKeyFn = Future<List<int>> Function({
  required String salt,
  required String passphrase,
  required int mCostKib,
  required int tCost,
  required int pCost,
});

typedef AeadFn = Future<List<int>> Function({
  required List<int> key,
  required List<int> data,
});

class SyncKeyManager {
  SyncKeyManager._();

  static const int kdfMemoryKiB = 64 * 1024;
  static const int kdfIterations = 3;
  static const int kdfParallelism = 4;

  @visibleForTesting
  static DeriveKeyFn deriveKey = _rustDeriveKey;
  @visibleForTesting
  static AeadFn aeadEncrypt = _rustEncrypt;
  @visibleForTesting
  static AeadFn aeadDecrypt = _rustDecrypt;

  static Future<List<int>> _rustDeriveKey({
    required String salt,
    required String passphrase,
    required int mCostKib,
    required int tCost,
    required int pCost,
  }) => crypto.Aes.deriveKey(
    salt: salt,
    userKey: passphrase,
    mCostKib: mCostKib,
    tCost: tCost,
    pCost: pCost,
  );

  static Future<List<int>> _rustEncrypt({
    required List<int> key,
    required List<int> data,
  }) => crypto.Aes.encrypt(key: key, data: data);

  static Future<List<int>> _rustDecrypt({
    required List<int> key,
    required List<int> data,
  }) => crypto.Aes.decrypt(key: key, encryptedData: data);

  static final Random _rng = .secure();

  static Uint8List _randomBytes(int n) =>
      .fromList(.generate(n, (_) => _rng.nextInt(256)));

  static List<int> generateDek() => _randomBytes(32);

  static Future<SyncKeyfile> wrapDek({
    required List<int> dek,
    required String passphrase,
  }) async {
    final saltB64 = base64Encode(_randomBytes(16));
    final kek = await deriveKey(
      salt: saltB64,
      passphrase: passphrase,
      mCostKib: kdfMemoryKiB,
      tCost: kdfIterations,
      pCost: kdfParallelism,
    );
    final wrapped = await aeadEncrypt(key: kek, data: dek);
    return SyncKeyfile(
      kdfMemoryKiB: kdfMemoryKiB,
      kdfIterations: kdfIterations,
      kdfParallelism: kdfParallelism,
      saltB64: saltB64,
      wrappedDekB64: base64Encode(wrapped),
    );
  }

  static Future<List<int>> unwrapDek({
    required SyncKeyfile keyfile,
    required String passphrase,
  }) async {
    final List<int> kek;
    try {
      kek = await deriveKey(
        salt: keyfile.saltB64,
        passphrase: passphrase,
        mCostKib: keyfile.kdfMemoryKiB,
        tCost: keyfile.kdfIterations,
        pCost: keyfile.kdfParallelism,
      );
    } catch (e) {
      throw SyncException(l10n.sync.errKdf(error: '$e'));
    }
    try {
      return await aeadDecrypt(
        key: kek,
        data: base64Decode(keyfile.wrappedDekB64),
      );
    } catch (_) {
      throw SyncException(l10n.sync.errWrongKeyPassword);
    }
  }

  static List<int>? _dekCache;
  static bool _dekLoaded = false;

  static Future<List<int>?> loadDek() async {
    if (_dekLoaded) return _dekCache;
    final raw = await MoodiarySecureKVs.syncDek.get();
    _dekCache = (raw == null || raw.isEmpty) ? null : base64Decode(raw);
    _dekLoaded = true;
    return _dekCache;
  }

  static Future<void> storeDek(List<int> dek) async {
    await MoodiarySecureKVs.syncDek.set(base64Encode(dek));
    _dekCache = dek;
    _dekLoaded = true;
  }

  static Future<void> clearDek() async {
    await MoodiarySecureKVs.syncDek.remove();
    _dekCache = null;
    _dekLoaded = true;
    MoodiaryKVs.syncKeyfileCache.set('');
    MoodiaryKVs.syncKeyfilePendingBackends.set(const <String>[]);
    MoodiaryKVs.syncKeyConflictBackends.set(const <String>[]);
  }

  static Future<SyncCipher> currentCipher() async => .withKey(await loadDek());

  @visibleForTesting
  static void resetForTest() {
    _dekCache = null;
    _dekLoaded = false;
    deriveKey = _rustDeriveKey;
    aeadEncrypt = _rustEncrypt;
    aeadDecrypt = _rustDecrypt;
  }

  static SyncKeyfile? cachedKeyfile() {
    final raw = MoodiaryKVs.syncKeyfileCache.get();
    if (raw == null || raw.isEmpty) return null;
    try {
      return .fromBytes(.fromList(utf8.encode(raw)));
    } catch (_) {
      return null;
    }
  }

  static void cacheKeyfile(SyncKeyfile keyfile) =>
      MoodiaryKVs.syncKeyfileCache.set(jsonEncode(keyfile.toJson()));

  static List<String> pendingUploadBackends() =>
      MoodiaryKVs.syncKeyfilePendingBackends.get() ?? const <String>[];

  static List<String> keyConflictBackends() =>
      MoodiaryKVs.syncKeyConflictBackends.get() ?? const <String>[];

  static bool hasKeyConflict(String? backendId) =>
      backendId != null && keyConflictBackends().contains(backendId);

  static void markKeyConflict(String? backendId) {
    if (backendId == null) return;
    final merged = {...keyConflictBackends(), backendId};
    MoodiaryKVs.syncKeyConflictBackends.set(merged.toList());
  }

  static void clearKeyConflict(String? backendId) {
    if (backendId == null) return;
    final rest = keyConflictBackends().where((b) => b != backendId).toList();
    MoodiaryKVs.syncKeyConflictBackends.set(rest);
  }

  static bool hasForceMediaReupload(String? backendId) =>
      backendId != null &&
      (MoodiaryKVs.syncForceMediaReuploadBackends.get() ?? const <String>[])
          .contains(backendId);

  static void markForceMediaReupload(String? backendId) {
    if (backendId == null) return;
    final merged = {
      ...MoodiaryKVs.syncForceMediaReuploadBackends.get() ?? const <String>[],
      backendId,
    };
    MoodiaryKVs.syncForceMediaReuploadBackends.set(merged.toList());
  }

  static void clearForceMediaReupload(String? backendId) {
    if (backendId == null) return;
    final rest =
        (MoodiaryKVs.syncForceMediaReuploadBackends.get() ?? const <String>[])
            .where((b) => b != backendId)
            .toList();
    MoodiaryKVs.syncForceMediaReuploadBackends.set(rest);
  }

  static Future<void> markPendingUpload(Iterable<String> backendIds) async {
    final merged = {...pendingUploadBackends(), ...backendIds};
    MoodiaryKVs.syncKeyfilePendingBackends.set(merged.toList());
  }

  static Future<void> clearPendingUpload(String backendId) async {
    final rest = pendingUploadBackends().where((b) => b != backendId).toList();
    MoodiaryKVs.syncKeyfilePendingBackends.set(rest);
  }

  static Future<SyncKeyfile?> readRemoteKeyfile(
    RemoteObjectStore backend,
  ) async {
    final bytes = await backend.readObject(SyncKeys.keysPath);
    if (bytes == null) return null;
    return .fromBytes(bytes);
  }

  static Future<void> writeRemoteKeyfile(
    RemoteObjectStore backend,
    SyncKeyfile keyfile,
  ) => backend.writeObject(SyncKeys.keysPath, keyfile.toBytes());

  static Future<void> deleteRemoteKeyfile(RemoteObjectStore backend) =>
      backend.deleteObject(SyncKeys.keysPath);

  static Future<RemoteKeyfileCheck> checkRemoteKeyfile(
    RemoteObjectStore backend,
  ) async {
    final SyncKeyfile? remote;
    final Uint8List? manifestBytes;
    try {
      remote = await readRemoteKeyfile(backend);
      if (remote == null) return .safe;
      manifestBytes = await backend.readObject(SyncKeys.manifestPath);
    } catch (_) {
      return .unknown;
    }
    final cached = cachedKeyfile();
    if (cached != null &&
        cached.saltB64 == remote.saltB64 &&
        cached.wrappedDekB64 == remote.wrappedDekB64) {
      return .safe;
    }
    if (manifestBytes == null || manifestBytes.isEmpty) return .unknown;
    if (!SyncCipher.isCipherText(manifestBytes)) return .safe;
    final dek = await loadDek();
    if (dek == null) return .conflict;
    try {
      await SyncCipher.withKey(dek).decode(manifestBytes);
      return .safe;
    } catch (_) {
      return .conflict;
    }
  }

  static Future<void> uploadPendingKeyfile(RemoteObjectStore backend) async {
    final backendId = backend.persistentBackendId;
    if (backendId == null || !pendingUploadBackends().contains(backendId)) {
      return;
    }
    final keyfile = cachedKeyfile();
    if (keyfile == null) {
      await clearPendingUpload(backendId);
      return;
    }
    switch (await checkRemoteKeyfile(backend)) {
      case .conflict:
        markKeyConflict(backendId);
        throw SyncKeyConflictException(l10n.sync.errKeyConflict);
      case .unknown:
        return;
      case .safe:
        await writeRemoteKeyfile(backend, keyfile);
        await clearPendingUpload(backendId);
        clearKeyConflict(backendId);
    }
  }

  static Future<bool> verifyPassphrase(
    String passphrase, {
    IRemoteSyncBackend? backend,
  }) async {
    final localDek = await loadDek();
    if (localDek == null) return false;
    SyncKeyfile? keyfile;
    if (backend != null && await backend.isReady()) {
      try {
        keyfile = await readRemoteKeyfile(backend);
      } catch (_) {
        keyfile = null;
      }
    }
    keyfile ??= cachedKeyfile();
    if (keyfile == null) return false;
    try {
      final dek = await unwrapDek(keyfile: keyfile, passphrase: passphrase);
      return listEquals(dek, localDek);
    } on SyncException {
      return false;
    }
  }
}
