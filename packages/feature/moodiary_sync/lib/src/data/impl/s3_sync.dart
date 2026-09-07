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

// 配置索引：0 endpoint、1 region（可空）、2 accessKey、3 secretKey、4 bucket、5 useSSL('1'/'0')。
@Named(SyncProviderIds.s3)
@LazySingleton(as: IRemoteSyncBackend)
class S3SyncBackend implements IRemoteSyncBackend {
  static const String _root = 'moodiary';

  S3SyncBackend(@Named(SyncProviderIds.s3) this._config);

  final SecureOptions _config;

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
      useSsl: _at(opts, 5) != '0',
      region: region.isEmpty ? null : region,
    );
  }

  String _objectName(String key) => '$_root/$key';

  @override
  Future<void> testConnection() async {
    final opts = await _read();
    if (!_ready(opts)) throw notReadyError;
    try {
      final client = await _client();
      if (!await client.testConnection()) {
        throw SyncException(
          l10n.sync.errBucketMissing(bucket: _at(opts, 4)),
          kind: .notFound,
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
      final bytes = await client.readObject(key: _objectName(key));
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
      await client.writeObject(key: _objectName(key), data: bytes);
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
      return await client.readObjectToFile(
        key: _objectName(key),
        filePath: filePath,
      );
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
      await client.writeObjectFile(key: _objectName(key), filePath: filePath);
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
      return await client.createExclusive(key: _objectName(key), data: bytes);
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
      await client.deleteObject(key: _objectName(key));
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
      final stat = await client.statObject(key: _objectName(key));
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
      SyncException(l10n.sync.errS3Config, kind: .notConfigured);

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
