library;

import 'dart:typed_data';

import 'package:fast_core/sync.dart' as rust;
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_sync/src/data/model/sync_provider.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:synchronized/synchronized.dart';

class S3SyncBackend implements IRemoteSyncBackend {
  static const String _root = 'moodiary';

  S3SyncBackend(this._options);

  final Future<List<String>> _options;
  final _clientLock = Lock();
  rust.S3Client? _cachedClient;

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
  Future<bool> isReady() async => _ready(await _options);

  Future<rust.S3Client> _client() async {
    return _cachedClient ??
        await _clientLock.synchronized(
          () async => _cachedClient ??= await _buildClient(),
        );
  }

  Future<rust.S3Client> _buildClient() async {
    final opts = await _options;
    await rust.FastCore.ensureInitialized();
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
    final opts = await _options;
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
  Future<ExclusiveCreate> tryCreateExclusive(
    String key,
    Uint8List bytes,
  ) async {
    try {
      final client = await _client();
      final result = await client.createExclusive(
        key: _objectName(key),
        data: bytes,
      );
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
      final prefix = _objectName('');
      return [
        for (final name in await client.listObjects(prefix: prefix))
          if (name.startsWith(prefix)) name.substring(prefix.length),
      ];
    } catch (e) {
      throw SyncException.wrap(e, (d) => l10n.sync.errListRemote(error: d));
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
  Future<List<String>> savedOptions() => _options;
}
