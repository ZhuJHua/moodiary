import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals, visibleForTesting;
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_rust/foundation.dart' as rust;
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_keyfile.dart';

/// [SyncKeyManager.checkRemoteKeyfile] 的判定结果。
enum RemoteKeyfileCheck {
  /// 远端没有信封、或远端密文本就是本机 DEK 加密的 —— 可以写。
  safe,

  /// 远端是另一把 DEK 加密的 —— 写下去远端数据就永久解不开了。
  conflict,

  /// 远端不可达，判不出来 —— 同样不写。
  unknown,
}

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

  /// 清除 DEK 及 keyfile 缓存 / 待上传清单 / 冲突标记（关闭加密）。
  static Future<void> clearDek() async {
    await MoodiarySecureKVs.syncDek.remove();
    _dekCache = null;
    _dekLoaded = true;
    MoodiaryKVs.syncKeyfileCache.set('');
    MoodiaryKVs.syncKeyfilePendingBackends.set(const <String>[]);
    MoodiaryKVs.syncKeyConflictBackends.set(const <String>[]);
    // syncForceMediaReuploadBackends **刻意不清**：它表达的是「远端那批媒体不可信、
    // 下次 push 必须重传」，与本机有没有密钥正交。关闭加密恰恰是它最需要生效的时刻
    // ——清掉它，那批用已销毁的 DEK 加密的媒体会被 stat 判成「远端已存在」而永不重传。
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

  // ── 密钥冲突标记 ──

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

  // ── 丢弃远端后的媒体强制重传标记 ──

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

  // ── 远端 keyfile ──

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

  /// 覆盖远端 keys.json 是否安全 —— 远端唯一的信封一旦被换掉，用它加密的日记与
  /// 媒体就永久解不开，所以任何写入前都要过这道判定。
  ///
  /// 判据不是「密码对不对」（没有远端密码就解不开远端信封），而是反过来：**用本机
  /// DEK 试解远端 manifest**。解得开 = 远端数据本就是这把 DEK 加密的，写入只是换个
  /// 密码包装（改密码 / 补传的正常场景）；解不开 = 那是别人的 DEK，必须中止。
  static Future<RemoteKeyfileCheck> checkRemoteKeyfile(
    RemoteObjectStore backend,
  ) async {
    final SyncKeyfile? remote;
    final Uint8List? manifestBytes;
    try {
      remote = await readRemoteKeyfile(backend);
      // 远端还没有信封：写入即初始化，孤立不了任何东西。
      if (remote == null) return .safe;
      manifestBytes = await backend.readObject(SyncKeys.manifestPath);
    } catch (_) {
      // 网络 / 鉴权故障：判不出来就不写，留着下次再试。
      return .unknown;
    }
    // 远端信封就是本机这一份（补传 / 改密码前的重写）：写下去什么都没改，无需再验。
    // 这条捷径也让「远端有信封但还没人 push 过 manifest」的正常两机场景不至于卡死。
    final cached = cachedKeyfile();
    if (cached != null &&
        cached.saltB64 == remote.saltB64 &&
        cached.wrappedDekB64 == remote.wrappedDekB64) {
      return .safe;
    }
    // 判「远端信封是残留、覆盖它是安全的」必须以**读到一份完好的明文 manifest**
    // 为条件。读不到（远端还没写过 manifest / 上次 push 传完媒体就中断）或读到
    // 0 字节（PUT 被截断，38195007 认过的真实故障态）都只说明我们**不知道**远端
    // 有没有密文——而信封一旦被换掉，用旧 DEK 加密的日记与媒体就永久解不开。
    if (manifestBytes == null || manifestBytes.isEmpty) return .unknown;
    // 远端是明文（关闭加密时删 keys.json 失败留下的残留信封）：孤立不了东西。
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

  /// 引擎同步前奏：本机 keyfile 缓存尚未送达当前后端（开启加密时离线 / 后端
  /// 后配 / 上次写失败）→ 补传。非 pending 时零成本。
  ///
  /// **写之前必过 [checkRemoteKeyfile]**：这条路径跑在引擎里、没有 UI 能弹密码框，
  /// 盲写会把另一台设备的信封换掉。冲突时挂上待处理标记并抛
  /// [SyncKeyConflictException] 中止本次同步，由用户在同步页输密码解锁。
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
        // pending 原样保留，下次同步再判。
        return;
      case .safe:
        await writeRemoteKeyfile(backend, keyfile);
        await clearPendingUpload(backendId);
        clearKeyConflict(backendId);
    }
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
