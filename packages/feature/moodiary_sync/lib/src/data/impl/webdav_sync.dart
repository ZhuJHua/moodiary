import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:moodiary_rust/moodiary_rust.dart' as rust;
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_sync/src/data/incremental_engine.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/model/sync_provider.dart';

/// WebDAV 实现 [IRemoteSyncBackend]，经 flutter_rust_bridge 调 Rust reqwest_dav。
/// 配置以 `[baseUrl, username, password]` 存于 [MoodiaryKVs.webDavOption]。
/// 增量逻辑交给 [IncrementalSyncEngine]。
class WebDavSyncBackend implements IRemoteSyncBackend {
  WebDavSyncBackend();

  Future<rust.DavClient>? _cachedClient;

  /// 构建 client 时的配置快照。每次取 client 与当前 KV 对比，配置变更后自动失效重建。
  List<String>? _cachedOptions;

  List<String> get _options =>
      MoodiaryKVs.webDavOption.get() ?? const <String>[];

  String get _baseUrl => _options.isNotEmpty ? _options[0] : '';
  String get _username => _options.length > 1 ? _options[1] : '';
  String get _password => _options.length > 2 ? _options[2] : '';

  @override
  SyncProviderType get type => SyncProviderType.webdav;

  @override
  String get persistentBackendId => SyncProviderType.webdav.value;

  @override
  String get displayName {
    if (_baseUrl.isEmpty) return 'WebDAV (未配置)';
    return 'WebDAV ($_baseUrl)';
  }

  @override
  bool get isReady => _baseUrl.isNotEmpty && _username.isNotEmpty;

  Future<rust.DavClient> _client() {
    final opts = _options;
    final cached = _cachedClient;
    if (cached != null && listEquals(_cachedOptions, opts)) return cached;
    final future = rust.DavClient.newInstance(
      baseUrl: _baseUrl,
      username: _username,
      password: _password,
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

  @override
  Future<String?> testConnection() async {
    if (!isReady) return '尚未配置 URL / 用户名';
    try {
      final client = await _client();
      final ok = await client.testConnection();
      return ok ? null : '连接失败';
    } catch (e) {
      return e.toString();
    }
  }

  /// 404 → null；其它错误（网络/认证/5xx）**必须**抛 [SyncException]、不可吞错 ——
  /// 引擎据此区分「首次同步」与「读取失败」，吞错会导致 manifest 被从零重建。
  @override
  Future<Uint8List?> readObject(String key) async {
    try {
      final client = await _client();
      final bytes = await client.readObject(key: key);
      return bytes.isEmpty ? null : bytes;
    } catch (e) {
      throw SyncException('读取远端对象失败（$key）：$e');
    }
  }

  @override
  Future<void> writeObject(String key, Uint8List bytes) async {
    final client = await _client();
    await client.writeObject(key: key, data: bytes);
  }

  @override
  Future<bool> tryCreateExclusive(String key, Uint8List bytes) async {
    try {
      final client = await _client();
      return await client.createExclusive(key: key, data: bytes);
    } catch (e) {
      throw SyncException('条件创建远端对象失败（$key）：$e');
    }
  }

  /// 404 已在 Rust 层视为成功；其它错误抛 [SyncException]，引擎据此决定
  /// tombstone 是否真的已被远端接收。
  @override
  Future<void> deleteObject(String key) async {
    try {
      final client = await _client();
      await client.deleteObject(key: key);
    } catch (e) {
      throw SyncException('删除远端对象失败（$key）：$e');
    }
  }

  @override
  Future<String> statObject(String key) async {
    try {
      final client = await _client();
      return await client.statObject(key: key);
    } catch (_) {
      return '';
    }
  }

  @override
  Future<SyncReport> pushAll() async {
    if (!isReady) throw const SyncException('请先完成 WebDAV 配置');
    return IncrementalSyncEngine(this).push();
  }

  @override
  Future<SyncReport> pullAll() async {
    if (!isReady) throw const SyncException('请先完成 WebDAV 配置');
    return IncrementalSyncEngine(this).pull();
  }

  @override
  Future<SyncReport> syncAll() async {
    if (!isReady) throw const SyncException('请先完成 WebDAV 配置');
    return IncrementalSyncEngine(this).sync();
  }

  static Future<void> configure({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    await MoodiaryKVs.webDavOption.set([
      baseUrl.trim(),
      username.trim(),
      password,
    ]);
  }

  static bool isConfigured() {
    final opts = MoodiaryKVs.webDavOption.get();
    return opts != null &&
        opts.length >= 3 &&
        opts[0].trim().isNotEmpty &&
        opts[1].trim().isNotEmpty;
  }

  static Future<void> clear() async {
    await MoodiaryKVs.webDavOption.set(const <String>[]);
  }
}
