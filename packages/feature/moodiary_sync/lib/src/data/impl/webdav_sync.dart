library;

import 'dart:typed_data';

import 'package:fast_core/sync.dart' as rust;
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_sync/src/data/model/sync_provider.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:synchronized/synchronized.dart';

class WebDavSyncBackend implements IRemoteSyncBackend {
  WebDavSyncBackend(this._options);

  final Future<List<String>> _options;
  final _clientLock = Lock();
  rust.DavClient? _cachedClient;

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
  Future<bool> isReady() async => _ready(await _options);

  Future<rust.DavClient> _client() async {
    return _cachedClient ??
        await _clientLock.synchronized(
          () async => _cachedClient ??= await _buildClient(),
        );
  }

  Future<rust.DavClient> _buildClient() async {
    final opts = await _options;
    await rust.FastCore.ensureInitialized();
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
  Future<ExclusiveCreate> tryCreateExclusive(
    String key,
    Uint8List bytes,
  ) async {
    try {
      final client = await _client();
      final result = await client.createExclusive(key: key, data: bytes);
      return switch (result) {
        rust.ExclusiveCreate.created => .created,
        rust.ExclusiveCreate.exists => .exists,
        rust.ExclusiveCreate.unsupported => .unsupported,
      };
    } catch (e) {
      throw SyncException.wrap(
        e,
        (d) => l10n.sync.errCreateRemote(key: key, error: d),
      );
    }
  }

  @override
  Future<List<String>> listObjects() async {
    try {
      final client = await _client();
      return await client.listObjects();
    } catch (e) {
      throw SyncException.wrap(e, (d) => l10n.sync.errListRemote(error: d));
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
  Future<List<String>> savedOptions() => _options;
}
