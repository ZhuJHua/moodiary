library;

import 'dart:async';
import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_rust/sync.dart' as rust;
import 'package:moodiary_sync/src/data/model/sync_provider.dart';
import 'package:moodiary_sync/src/data/remote_lease.dart';
import 'package:moodiary_sync/src/data/secure_options.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_key_manager.dart';

@Named(SyncProviderIds.webdav)
@LazySingleton(as: IRemoteSyncBackend)
class WebDavSyncBackend implements IRemoteSyncBackend {
  WebDavSyncBackend(@Named(SyncProviderIds.webdav) this._config);

  final SecureOptions _config;

  Future<List<String>>? _options;
  Future<rust.DavClient>? _cachedClient;

  Future<List<String>> _read() => _options ??= _config.read();

  static String _at(List<String> o, int i) => o.length > i ? o[i] : '';

  static bool _ready(List<String> o) =>
      _at(o, 0).isNotEmpty && _at(o, 1).isNotEmpty;

  @override
  SyncProviderType get type => .webdav;

  @override
  String get persistentBackendId => SyncProviderType.webdav.value;

  @override
  String get displayName => type.label;

  @override
  Future<bool> isReady() async => _ready(await _read());

  Future<rust.DavClient> _client() {
    final cached = _cachedClient;
    if (cached != null) return cached;
    final future = _buildClient().onError((
      Object error,
      StackTrace stackTrace,
    ) {
      _cachedClient = null;
      Error.throwWithStackTrace(error, stackTrace);
    });
    _cachedClient = future;
    return future;
  }

  Future<rust.DavClient> _buildClient() async {
    final opts = await _read();
    await rust.MoodiaryRust.ensureInitialized();
    return rust.DavClient.newInstance(
      baseUrl: _at(opts, 0),
      username: _at(opts, 1),
      password: _at(opts, 2),
    );
  }

  @override
  Future<void> testConnection() async {
    if (!await isReady()) throw notReadyError;
    try {
      final client = await _client();
      if (!await client.testConnection()) {
        throw SyncException(
          l10n.sync.connectFailed(error: l10n.sync.healthUnreachableShort),
          kind: .http,
        );
      }
    } catch (e) {
      throw SyncException.wrap(e, (d) => l10n.sync.connectFailed(error: d));
    }
  }

  @override
  Future<Uint8List?> readObject(String key) async {
    try {
      final client = await _client();
      final bytes = await client.readObject(key: key);
      return bytes;
    } catch (e) {
      throw SyncException.wrap(
        e,
        (d) => l10n.sync.errReadRemote(key: key, error: d),
      );
    }
  }

  @override
  Future<void> writeObject(String key, Uint8List bytes) async {
    try {
      final client = await _client();
      await client.writeObject(key: key, data: bytes);
    } catch (e) {
      throw SyncException.wrap(
        e,
        (d) => l10n.sync.errWriteRemote(key: key, error: d),
      );
    }
  }

  @override
  bool get supportsFileObjects => true;

  @override
  Future<bool> readObjectToFile(String key, String filePath) async {
    try {
      final client = await _client();
      return await client.readObjectToFile(key: key, filePath: filePath);
    } catch (e) {
      throw SyncException.wrap(
        e,
        (d) => l10n.sync.errReadRemote(key: key, error: d),
      );
    }
  }

  @override
  Future<void> writeObjectFile(String key, String filePath) async {
    try {
      final client = await _client();
      await client.writeObjectFile(key: key, filePath: filePath);
    } catch (e) {
      throw SyncException.wrap(
        e,
        (d) => l10n.sync.errWriteRemote(key: key, error: d),
      );
    }
  }

  @override
  Future<bool> tryCreateExclusive(String key, Uint8List bytes) async {
    try {
      final client = await _client();
      return await client.createExclusive(key: key, data: bytes);
    } catch (e) {
      throw SyncException.wrap(
        e,
        (d) => l10n.sync.errCreateRemote(key: key, error: d),
      );
    }
  }

  @override
  Future<void> deleteObject(String key) async {
    try {
      final client = await _client();
      await client.deleteObject(key: key);
    } catch (e) {
      throw SyncException.wrap(
        e,
        (d) => l10n.sync.errDeleteRemote(key: key, error: d),
      );
    }
  }

  @override
  Future<String?> statObject(String key) async {
    try {
      final client = await _client();
      // Rust 侧只在 404 返回空串，网络错误与 401/5xx 都抛
      final stat = await client.statObject(key: key);
      return stat.isEmpty ? null : stat;
    } catch (e) {
      throw SyncException.wrap(
        e,
        (d) => l10n.sync.errStatRemote(key: key, error: d),
      );
    }
  }

  @override
  SyncException get notReadyError =>
      SyncException(l10n.sync.errWebdavConfig, kind: .notConfigured);

  @override
  Future<List<String>> savedOptions() => _read();

  @override
  Future<void> saveOptions(List<String> options) async {
    await _config.save(options);
    _options = null;
    _cachedClient = null;
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
