import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals, visibleForTesting;
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_rust/moodiary_rust.dart' as rust;
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_keyfile.dart';

/// KDF 原语签名（可注入：宿主单测无 Rust FFI，用纯 Dart 假实现）。
typedef DeriveKeyFn = Future<List<int>> Function({
  required String salt,
  required String passphrase,
  required int mCostKib,
  required int tCost,
  required int pCost,
});

/// AEAD 原语签名（加密 = 12B nonce + 密文 + 16B tag，解密失败抛异常）。
typedef AeadFn = Future<List<int>> Function({
  required List<int> key,
  required List<int> data,
});

/// 同步密钥管理 —— 信封加密的编排中枢。
///
/// - **DEK**（32B 纯随机）：加密所有同步对象，只存本机 SecureKV（[MoodiarySecureKVs.syncDek]）；
/// - **KEK** = Argon2id(用户密码, 随机盐)：只用来包 DEK，密码原文不落任何存储；
/// - **keyfile**（远端 `keys.json` + 本机明文缓存）：盐 + KDF 参数 + 包好的 DEK。
///   改密码 = 重包 keyfile（单对象原子写），数据零重写；
/// - **待上传清单**（[MoodiaryKVs.syncKeyfilePendingBackends]）：开启加密 / 改密码时
///   把 keyfile 写到所有已配置后端，离线或失败的记入清单，该后端下次同步由引擎
///   前奏补传（[uploadPendingKeyfile]）。
class SyncKeyManager {
  SyncKeyManager._();

  /// Argon2id 默认参数（OWASP 推荐档，与 Rust 侧一致），写入新 keyfile；
  /// 解包一律按 keyfile 所记参数执行，未来升级强度不破坏旧 keyfile。
  static const int kdfMemoryKiB = 64 * 1024;
  static const int kdfIterations = 3;
  static const int kdfParallelism = 4;

  /// 可注入的加密原语（默认 Rust 实现；宿主单测注入纯 Dart 假实现）。
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
  }) => rust.Aes.deriveKey(
    salt: salt,
    userKey: passphrase,
    mCostKib: mCostKib,
    tCost: tCost,
    pCost: pCost,
  );

  static Future<List<int>> _rustEncrypt({
    required List<int> key,
    required List<int> data,
  }) => rust.Aes.encrypt(key: key, data: data);

  static Future<List<int>> _rustDecrypt({
    required List<int> key,
    required List<int> data,
  }) => rust.Aes.decrypt(key: key, encryptedData: data);

  static final Random _rng = .secure();

  static Uint8List _randomBytes(int n) =>
      .fromList(.generate(n, (_) => _rng.nextInt(256)));

  /// 生成新的 32 字节随机数据密钥。
  static List<int> generateDek() => _randomBytes(32);

  /// 用 [passphrase] 把 [dek] 包成 keyfile：随机 16B 盐（base64 字符串的字节作
  /// KDF 盐），KEK 派生后 AES-GCM 封装。
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

  /// 解包 keyfile。密码错 = AES-GCM tag 校验失败 → [SyncException]；
  /// KDF 派生失败（参数异常等）单独包装，不向调用方漏裸异常。
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

  // ── 本机 DEK ──

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

  /// 清除 DEK 及 keyfile 缓存 / 待上传清单（关闭加密）。
  static Future<void> clearDek() async {
    await MoodiarySecureKVs.syncDek.remove();
    _dekCache = null;
    _dekLoaded = true;
    MoodiaryKVs.syncKeyfileCache.set('');
    MoodiaryKVs.syncKeyfilePendingBackends.set(const <String>[]);
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

  // ── keyfile 本机缓存与待上传清单 ──

  /// 最近一次读到 / 写出的 keyfile（明文缓存，非机密）；损坏当作不存在。
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

  static Future<void> markPendingUpload(Iterable<String> backendIds) async {
    final merged = {...pendingUploadBackends(), ...backendIds};
    MoodiaryKVs.syncKeyfilePendingBackends.set(merged.toList());
  }

  static Future<void> clearPendingUpload(String backendId) async {
    final rest = pendingUploadBackends().where((b) => b != backendId).toList();
    MoodiaryKVs.syncKeyfilePendingBackends.set(rest);
  }

  // ── 远端 keyfile ──

  static Future<SyncKeyfile?> readRemoteKeyfile(
    IRemoteSyncBackend backend,
  ) async {
    final bytes = await backend.readObject(SyncKeys.keysPath);
    if (bytes == null) return null;
    return .fromBytes(bytes);
  }

  static Future<void> writeRemoteKeyfile(
    IRemoteSyncBackend backend,
    SyncKeyfile keyfile,
  ) => backend.writeObject(SyncKeys.keysPath, keyfile.toBytes());

  static Future<void> deleteRemoteKeyfile(IRemoteSyncBackend backend) =>
      backend.deleteObject(SyncKeys.keysPath);

  /// 引擎同步前奏：本机 keyfile 缓存尚未送达当前后端（开启加密时离线 / 后端
  /// 后配 / 上次写失败）→ 补传。非 pending 时零成本。失败如实上抛（由调用方
  /// 记日志后继续同步，pending 保留下次再试）。
  static Future<void> uploadPendingKeyfile(IRemoteSyncBackend backend) async {
    final backendId = backend.persistentBackendId;
    if (backendId == null || !pendingUploadBackends().contains(backendId)) {
      return;
    }
    final keyfile = cachedKeyfile();
    if (keyfile == null) {
      await clearPendingUpload(backendId);
      return;
    }
    await writeRemoteKeyfile(backend, keyfile);
    await clearPendingUpload(backendId);
  }

  /// 校验密码：优先对着远端 keyfile（后端可达时），离线回退本机缓存；解包出的
  /// DEK 必须与本机一致。无任何 keyfile 可校验 → false。
  static Future<bool> verifyPassphrase(
    String passphrase, {
    IRemoteSyncBackend? backend,
  }) async {
    final localDek = await loadDek();
    if (localDek == null) return false;
    SyncKeyfile? keyfile;
    if (backend != null && backend.isReady) {
      try {
        keyfile = await readRemoteKeyfile(backend);
      } catch (_) {
        keyfile = null; // 远端不可达 → 回退本机缓存
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
