/// @docImport 'package:moodiary_http/moodiary_http.dart';
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_rust/sync.dart' as rust;
import 'package:moodiary_sync/src/data/incremental_engine.dart';
import 'package:moodiary_sync/src/data/model/sync_provider.dart';
import 'package:moodiary_sync/src/data/remote_lease.dart';
import 'package:moodiary_sync/src/data/secure_options.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_key_manager.dart';

/// S3 / MinIO 实现 [IRemoteSyncBackend]，经 flutter_rust_bridge 调 Rust minio SDK。
/// 配置存于 [MoodiarySecureKVs.s3Option]（含 secretKey），按索引：0 endpoint、1 region（可空）、
/// 2 accessKey、3 secretKey、4 bucket、5 useSSL（'1'/'0'）。
/// 远端 key 前缀 `moodiary/`。
/// 增量逻辑交给 [IncrementalSyncEngine]。
@Named(SyncProviderIds.s3)
@LazySingleton(as: IRemoteSyncBackend)
class S3SyncBackend implements IRemoteSyncBackend {
  static const String _root = 'moodiary';

  S3SyncBackend(@Named(SyncProviderIds.s3) this._config);

  final SecureOptions _config;

  /// 配置与 client 都是首次用到才从钥匙串读、建，之后缓存在后端自己身上；
  /// 配置只经 [saveOptions] / [clearOptions] 改动，两处直接作废。
  Future<List<String>>? _options;
  Future<rust.S3Client>? _cachedClient;

  Future<List<String>> _read() => _options ??= _config.read();

  static String _at(List<String> o, int i) => o.length > i ? o[i] : '';

  static bool _ready(List<String> o) =>
      _at(o, 0).isNotEmpty &&
      _at(o, 2).isNotEmpty &&
      _at(o, 3).isNotEmpty &&
      _at(o, 4).isNotEmpty;

  @override
  SyncProviderType get type => .s3;

  @override
  String get persistentBackendId => SyncProviderType.s3.value;

  @override
  String get displayName => type.label;

  @override
  Future<bool> isReady() async => _ready(await _read());

  Future<rust.S3Client> _client() {
    final cached = _cachedClient;
    if (cached != null) return cached;
    final future = _buildClient().onError((
      Object error,
      StackTrace stackTrace,
    ) {
      // 构造失败的 Future 不能留缓存，否则后续操作会复用同一失败结果直到重启。
      _cachedClient = null;
      Error.throwWithStackTrace(error, stackTrace);
    });
    _cachedClient = future;
    return future;
  }

  Future<rust.S3Client> _buildClient() async {
    final opts = await _read();
    await rust.MoodiaryRust.ensureInitialized();
    final region = _at(opts, 1);
    return rust.S3Client.newInstance(
      endpoint: _at(opts, 0),
      accessKey: _at(opts, 2),
      secretKey: _at(opts, 3),
      bucket: _at(opts, 4),
      useSsl: _at(opts, 5) != '0', // 默认开启
      region: region.isEmpty ? null : region,
    );
  }

  String _objectName(String key) => '$_root/$key';

  @override
  Future<String?> testConnection() async {
    final opts = await _read();
    if (!_ready(opts)) return '尚未配置 endpoint / 凭据 / bucket';
    try {
      final client = await _client();
      final exists = await client.testConnection();
      return exists ? null : 'Bucket "${_at(opts, 4)}" 不存在';
    } catch (e) {
      return e.toString();
    }
  }

  /// 不存在（NoSuchKey 等）→ null；其它错误**必须**抛 [SyncException]、不可吞错 ——
  /// 引擎据此区分「首次同步」与「读取失败」，吞错会导致 manifest 被从零重建。
  ///
  /// **0 字节对象不是「不存在」**：Rust 侧用 `Option` 表达 404，这里原样透传。
  /// 曾经两边都用空 Vec 编码 404，于是被截断的 0 字节 manifest.json 会被当成
  /// 「远端为空」，push 用本机数据重建 manifest —— 远端墓碑全丢、已删日记在其它
  /// 设备复活。0 字节现在如实返回空 [Uint8List]，交给 manifest 的损坏守卫处理。
  @override
  Future<Uint8List?> readObject(String key) async {
    try {
      final client = await _client();
      final bytes = await client.readObject(key: _objectName(key));
      return bytes;
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
  SyncException get notReadyError => SyncException(l10n.sync.errS3Config);

  @override
  Future<List<String>> savedOptions() => _read();

  @override
  Future<void> saveOptions(List<String> options) async {
    await _config.save(options);
    _options = null;
    _cachedClient = null;
    // 服务器可能换了：进程内的条件写探测结论作废，下次抢占重新探测。
    RemoteLease.resetCasProbeCache();
    if (await SyncKeyManager.loadDek() != null) {
      await SyncKeyManager.markPendingUpload([type.value]);
    }
  }

  @override
  Future<void> clearOptions() async {
    await _config.clear();
    _options = null;
    _cachedClient = null;
    RemoteLease.resetCasProbeCache();
  }
}
