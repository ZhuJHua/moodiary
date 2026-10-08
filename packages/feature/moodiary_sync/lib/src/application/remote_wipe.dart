import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_sync/src/application/re_cipher.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/incremental_engine.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/remote_lease.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_key_manager.dart';
import 'package:moodiary_sync/src/data/sync_keyfile.dart';
import 'package:pool/pool.dart';

class RemoteWipeReport {
  final int deleted;
  final int failed;

  const RemoteWipeReport({required this.deleted, required this.failed});
}

typedef _NewKey = ({List<int> dek, SyncKeyfile keyfile});

abstract final class RemoteWipe {
  static const _envelope = [SyncKeys.manifestPath, SyncKeys.keysPath];

  static final _unsafeKey = RegExp(r'(^|/)\.\.?(/|$)|[%?#\\]');

  static Future<RemoteWipeReport> run(
    IRemoteSyncBackend backend, {
    required String? passphrase,
    Set<String> configured = const {},
    ReCipherProgress? onProgress,
  }) async {
    final key = passphrase == null ? null : await _newKey(passphrase);
    return IncrementalSyncEngine.runExclusive(
      () => RemoteLease.protect(backend, () async {
        final report = await _wipe(backend, onProgress);
        await _reseed(backend, key, configured);
        return report;
      }),
    );
  }

  static Future<_NewKey> _newKey(String passphrase) async {
    final dek = SyncKeyManager.generateDek();
    return (
      dek: dek,
      keyfile: await SyncKeyManager.wrapDek(dek: dek, passphrase: passphrase),
    );
  }

  static Future<RemoteWipeReport> _wipe(
    IRemoteSyncBackend backend,
    ReCipherProgress? onProgress,
  ) async {
    final rest = (await backend.listObjects())
        .where(
          (k) =>
              k != SyncKeys.lockPath &&
              !_envelope.contains(k) &&
              !_unsafeKey.hasMatch(k),
        )
        .toList();
    final total = _envelope.length + rest.length;
    var done = 0;

    for (final key in _envelope) {
      await backend.deleteObject(key);
      onProgress?.call(++done, total, key);
    }

    final pool = Pool(IncrementalSyncEngine.resolveConcurrency());
    Future<List<String>> deleteAll(List<String> keys) async {
      final failed = <String>[];
      await Future.wait(
        keys.map(
          (key) => pool.withResource(() async {
            try {
              await backend.deleteObject(key);
              onProgress?.call(++done, total, key);
            } catch (_) {
              failed.add(key);
            }
          }),
        ),
      );
      return failed;
    }

    final failed = await deleteAll(await deleteAll(rest));
    await pool.close();
    return RemoteWipeReport(
      deleted: total - failed.length,
      failed: failed.length,
    );
  }

  static Future<void> _reseed(
    IRemoteSyncBackend backend,
    _NewKey? key,
    Set<String> configured,
  ) async {
    if (key != null &&
        !await SyncKeyManager.claimRemoteKeyfile(backend, key.keyfile)) {
      throw SyncKeyConflictException(l10n.sync.errKeyConflict);
    }
    await backend.writeObject(
      SyncKeys.manifestPath,
      await SyncCipher.withKey(key?.dek).encode(SyncManifest.empty().toJson()),
    );
    final id = backend.persistentBackendId;
    if (key == null) {
      await SyncKeyManager.clearDek();
    } else {
      await SyncKeyManager.installKey(
        dek: key.dek,
        keyfile: key.keyfile,
        backendId: id,
        configured: configured,
      );
    }
    SyncKeyManager.markForceMediaReupload(id);
  }
}
