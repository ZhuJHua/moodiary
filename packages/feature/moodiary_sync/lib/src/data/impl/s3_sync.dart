/// @docImport 'package:moodiary_http/moodiary_http.dart';
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_rust/sync.dart' as rust;
import 'package:moodiary_sync/src/data/incremental_engine.dart';
import 'package:moodiary_sync/src/data/model/sync_provider.dart';
import 'package:moodiary_sync/src/data/secure_options.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_key_manager.dart';

/// S3 / MinIO 实现 [IRemoteSyncBackend]，经 flutter_rust_bridge 调 Rust minio SDK。
/// 配置存于 [MoodiarySecureKVs.s3Option]（含 secretKey），按索引：0 endpoint、1 region（可空）、
/// 2 accessKey、3 secretKey、4 bucket、5 useSSL（'1'/'0'）。
/// 远端 key 前缀 `moodiary/`。
/// 增量逻辑交给 [IncrementalSyncEngine]。
class S3SyncBackend implements IRemoteSyncBackend {
  static const String _root = 'moodiary';

  static final SecureOptions options = SecureOptions(.s3Option);

  S3SyncBackend();

  Future<rust.S3Client>? _cachedClient;

  /// 构建 client 时的配置快照。每次取 client 与当前 KV 对比，配置变更后自动失效重建。
  List<String>? _cachedOptions;

  List<String> get _options => options.value;

  String _opt(int i) => _options.length > i ? _options[i] : '';

  String get _endpoint => _opt(0);
  String? get _region => _opt(1).isEmpty ? null : _opt(1);
  String get _accessKey => _opt(2);
  String get _secretKey => _opt(3);
  String get _bucket => _opt(4);
  bool get _useSSL => _opt(5) != '0'; // 默认开启

  @override
  SyncProviderType get type => .s3;

  @override
  String get persistentBackendId => SyncProviderType.s3.value;

  @override
  String get displayName {
    if (_endpoint.isEmpty || _bucket.isEmpty) return 'S3 / MinIO (未配置)';
    return 'S3 / MinIO ($_endpoint • $_bucket)';
  }

  @override
  bool get isReady =>
      _endpoint.isNotEmpty &&
      _accessKey.isNotEmpty &&
      _secretKey.isNotEmpty &&
      _bucket.isNotEmpty;

  Future<rust.S3Client> _client() {
    final opts = _options;
    final cached = _cachedClient;
    if (cached != null && listEquals(_cachedOptions, opts)) return cached;
    final future =
        rust.S3Client.newInstance(
          endpoint: _endpoint,
          accessKey: _accessKey,
          secretKey: _secretKey,
          bucket: _bucket,
          useSsl: _useSSL,
          region: _region,
        ).onError((Object error, StackTrace stackTrace) {
          // 构造失败的 Future 不能留缓存，否则后续操作会复用同一失败结果直到重启。
          _cachedClient = null;
          _cachedOptions = null;
          Error.throwWithStackTrace(error, stackTrace);
        });
    _cachedClient = future;
    _cachedOptions = opts;
    return future;
  }

  String _objectName(String key) => '$_root/$key';

  @override
  Future<String?> testConnection() async {
    if (!isReady) return '尚未配置 endpoint / 凭据 / bucket';
    try {
      final client = await _client();
      final exists = await client.testConnection();
      return exists ? null : 'Bucket "$_bucket" 不存在';
    } catch (e) {
      return e.toString();
    }
  }

  /// 不存在（NoSuchKey 等）→ null；其它错误**必须**抛 [SyncException]、不可吞错 ——
  /// 引擎据此区分「首次同步」与「读取失败」，吞错会导致 manifest 被从零重建。
  @override
  Future<Uint8List?> readObject(String key) async {
    try {
      final client = await _client();
      final bytes = await client.readObject(key: _objectName(key));
      return bytes.isEmpty ? null : bytes;
    } catch (e) {
      throw SyncException(l10n.sync.errReadRemote(key: key, error: '$e'));
    }
  }

  @override
  Future<void> writeObject(String key, Uint8List bytes) async {
    final client = await _client();
    await client.writeObject(key: _objectName(key), data: bytes);
  }

  @override
  bool get supportsFileObjects => true;

  @override
  Future<bool> readObjectToFile(String key, String filePath) async {
    try {
      final client = await _client();
      return await client.readObjectToFile(
        key: _objectName(key),
        filePath: filePath,
      );
    } catch (e) {
      throw SyncException(l10n.sync.errReadRemote(key: key, error: '$e'));
    }
  }

  @override
  Future<void> writeObjectFile(String key, String filePath) async {
    final client = await _client();
    await client.writeObjectFile(key: _objectName(key), filePath: filePath);
  }

  @override
  Future<bool> tryCreateExclusive(String key, Uint8List bytes) async {
    try {
      final client = await _client();
      return await client.createExclusive(key: _objectName(key), data: bytes);
    } catch (e) {
      throw SyncException(l10n.sync.errCreateRemote(key: key, error: '$e'));
    }
  }

  /// 不存在已在 Rust 层视为成功；其它错误抛 [SyncException]，引擎据此决定
  /// tombstone 是否真的已被远端接收。
  @override
  Future<void> deleteObject(String key) async {
    try {
      final client = await _client();
      await client.deleteObject(key: _objectName(key));
    } catch (e) {
      throw SyncException('删除远端对象失败（$key）：$e');
    }
  }

  @override
  Future<String?> statObject(String key) async {
    try {
      final client = await _client();
      // Rust 侧只在 404 返回空串（网络错误与 401/5xx 都抛），这里映射成 null。
      final stat = await client.statObject(key: _objectName(key));
      return stat.isEmpty ? null : stat;
    } catch (e) {
      throw SyncException('查询远端对象失败（$key）：$e');
    }
  }

  @override
  Future<SyncReport> pushAll() async {
    if (!isReady) throw SyncException(l10n.sync.errS3Config);
    return IncrementalSyncEngine(this).push();
  }

  @override
  Future<SyncReport> pullAll() async {
    if (!isReady) throw SyncException(l10n.sync.errS3Config);
    return IncrementalSyncEngine(this).pull();
  }

  @override
  Future<SyncReport> syncAll() async {
    if (!isReady) throw SyncException(l10n.sync.errS3Config);
    return IncrementalSyncEngine(this).sync();
  }

  static Future<void> configure({
    required String endpoint,
    required String region,
    required String accessKey,
    required String secretKey,
    required String bucket,
    required bool useSSL,
  }) async {
    await options.save([
      endpoint.trim(),
      region.trim(),
      accessKey.trim(),
      secretKey,
      bucket.trim(),
      useSSL ? '1' : '0',
    ]);
    // 同 WebDavSyncBackend.configure：加密已开启时登记 keyfile 待上传。
    if (await SyncKeyManager.loadDek() != null) {
      await SyncKeyManager.markPendingUpload([SyncProviderType.s3.value]);
    }
  }

  static bool isConfigured() {
    final opts = options.value;
    return opts.length >= 5 &&
        opts[0].trim().isNotEmpty &&
        opts[2].trim().isNotEmpty &&
        opts[3].isNotEmpty &&
        opts[4].trim().isNotEmpty;
  }

  static Future<void> clear() async {
    await options.clear();
  }
}
