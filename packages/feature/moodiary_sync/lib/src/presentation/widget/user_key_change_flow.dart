import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_sync/src/application/re_cipher.dart';
import 'package:moodiary_sync/src/application/remote_wipe.dart';
import 'package:moodiary_sync/src/application/user_key_controller.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/remote_lease.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_key_manager.dart';
import 'package:moodiary_sync/src/data/sync_keyfile.dart';
import 'package:moodiary_sync/src/data/sync_provider_scope.dart';

Future<bool> applyUserKeyChange({
  required BuildContext context,
  required WidgetRef ref,
  required String? newKey,
}) async {
  final dek = await SyncKeyManager.loadDek();
  final target = (newKey == null || newKey.trim().isEmpty)
      ? null
      : newKey.trim();

  if (dek == null && target == null) return true;

  final backend = currentSyncBackend();
  final backendReady = backend != null && await backend.isReady();

  if (dek != null && target != null) {
    final keyfile = await SyncKeyManager.wrapDek(dek: dek, passphrase: target);
    SyncKeyManager.cacheKeyfile(keyfile);
    await SyncKeyManager.markPendingUpload(await configuredCloudBackendIds());
    if (backendReady) {
      final check = await SyncKeyManager.checkRemoteKeyfile(backend);
      if (check == .conflict) {
        SyncKeyManager.markKeyConflict(backend.persistentBackendId);
        if (context.mounted) {
          toast.error(message: l10n.sync.keyChangedLocalOnly);
        }
        return true;
      }
      if (check == .safe) {
        try {
          await SyncKeyManager.writeRemoteKeyfile(backend, keyfile);
          final id = backend.persistentBackendId;
          if (id != null) await SyncKeyManager.clearPendingUpload(id);
        } catch (_) {}
      }
    }
    if (context.mounted) {
      toast.success(message: l10n.sync.keyChanged);
    }
    return true;
  }

  if (dek == null && target != null) {
    SyncKeyfile? remoteKeyfile;
    Uint8List? remoteManifest;
    if (backendReady) {
      try {
        remoteKeyfile = await SyncKeyManager.readRemoteKeyfile(backend);
        remoteManifest = await backend.readObject(SyncKeys.manifestPath);
      } catch (e) {
        if (context.mounted) {
          toast.error(message: l10n.sync.keyRemoteProbeFailed(error: '$e'));
        }
        return false;
      }
    }

    final remoteIsPlaintext =
        remoteManifest != null &&
        remoteManifest.isNotEmpty &&
        !SyncCipher.isCipherText(remoteManifest);
    var staleEnvelope = false;
    if (remoteKeyfile != null && remoteIsPlaintext) {
      remoteKeyfile = null;
      staleEnvelope = true;
    }

    if (remoteKeyfile != null) {
      if (!context.mounted) return false;
      final outcome = await _adoptRemoteKey(
        context: context,
        ref: ref,
        backend: backend!,
        keyfile: remoteKeyfile,
        passphrase: target,
      );
      switch (outcome) {
        case .unlocked:
          return true;
        case .cancelled:
          return false;
        case .reset:
          if (!context.mounted) return false;
          return resetRemote(
            context: context,
            ref: ref,
            backend: backend,
            passphrase: target,
          );
      }
    }

    final hasRemote =
        backendReady &&
        remoteKeyfile == null &&
        remoteManifest != null &&
        remoteManifest.isNotEmpty;

    if (hasRemote) {
      if (!context.mounted) return false;
      final confirmed = await MAlert.confirm(
        context,
        title: l10n.sync.keyEncryptCloudTitle,
        message: l10n.sync.keyEncryptCloudMessage,
        confirmLabel: l10n.sync.keyContinue,
        barrierDismissible: false,
      );
      if (!confirmed) return false;
    }

    final newDek = SyncKeyManager.generateDek();
    final keyfile = await SyncKeyManager.wrapDek(
      dek: newDek,
      passphrase: target,
    );
    if (backendReady) {
      final remote = backend;
      try {
        await RemoteLease.protect(remote, () async {
          if (!await SyncKeyManager.claimRemoteKeyfile(
            remote,
            keyfile,
            replaceStale: staleEnvelope,
          )) {
            throw SyncKeyConflictException(l10n.sync.errKeyConflict);
          }
        });
      } catch (e) {
        if (context.mounted) {
          toast.error(message: l10n.sync.keyWriteFailed(error: '$e'));
        }
        return false;
      }
    }
    await SyncKeyManager.installKey(
      dek: newDek,
      keyfile: keyfile,
      backendId: backendReady ? backend.persistentBackendId : null,
      configured: await configuredCloudBackendIds(),
    );
    if (context.mounted) ref.invalidate(syncDekControllerProvider);

    if (hasRemote) {
      if (context.mounted) await _encryptCloud(context, backend, newDek);
    } else if (context.mounted) {
      toast.success(message: l10n.sync.keyEncryptionOn);
    }
    return true;
  }

  if (!context.mounted) return false;
  final confirmed = await MAlert.confirm(
    context,
    title: l10n.sync.keyDecryptTitle,
    message: l10n.sync.keyDecryptMessage,
    confirmLabel: l10n.sync.keyContinue,
    barrierDismissible: false,
  );
  if (!confirmed || !context.mounted) return false;
  if (!await AppAuth.verify(context, .syncKeyDisable)) return false;

  if (backendReady) {
    if (!context.mounted) return false;
    final report = await _runWithProgress(
      context,
      backend: backend,
      from: .withKey(dek),
      to: .plaintext,
    );
    if (report == null) {
      final stillHasRemote = await _remoteExists(backend);
      if (stillHasRemote) return false;
      SyncKeyManager.markForceMediaReupload(backend.persistentBackendId);
    } else if (report.failed > 0) {
      if (context.mounted) {
        toast.error(
          message: l10n.sync.keyDecryptPartial(failed: report.failed),
        );
      }
      return false;
    }
    try {
      await SyncKeyManager.deleteRemoteKeyfile(backend);
    } catch (_) {}
  }
  await SyncKeyManager.clearDek();
  if (context.mounted) ref.invalidate(syncDekControllerProvider);
  if (context.mounted) toast.success(message: l10n.sync.keyEncryptionOff);
  return true;
}

Future<bool> _encryptCloud(
  BuildContext context,
  IRemoteSyncBackend backend,
  List<int> dek,
) async {
  final report = await _runWithProgress(
    context,
    backend: backend,
    from: .plaintext,
    to: .withKey(dek),
  );
  if (report == null) return false;
  if (report.failed > 0) {
    toast.error(message: l10n.sync.keyEncryptPartial(failed: report.failed));
    return false;
  }
  toast.success(message: l10n.sync.keyCloudEncrypted(report: report));
  return true;
}

enum _DecryptedChoice { turnOff, encrypt }

Future<bool> resolveDecryptedRemote({
  required BuildContext context,
  required WidgetRef ref,
  required IRemoteSyncBackend backend,
}) async {
  final id = backend.persistentBackendId;
  final keyfile = SyncKeyManager.cachedKeyfile();
  final choice = await MAlert.show<_DecryptedChoice>(
    context,
    title: l10n.sync.keyRemoteDecryptedTitle,
    message: l10n.sync.keyRemoteDecryptedMessage,
    icon: LucideIcons.lockKeyholeOpen,
    actionsLayout: .vertical,
    actions: [
      if (keyfile != null)
        MAction(
          label: l10n.sync.keyRemoteDecryptedEncrypt,
          value: .encrypt,
          isPrimary: true,
        ),
      MAction(label: l10n.sync.keyRemoteDecryptedTurnOff, value: .turnOff),
      MAction(label: l10n.sync.keyNotNow),
    ],
  );
  if (!context.mounted) return false;
  switch (choice) {
    case null:
      SyncKeyManager.markKeyConflict(id);
      return false;
    case .turnOff:
      if (!await AppAuth.verify(context, .syncKeyDisable)) return false;
      await SyncKeyManager.clearDek();
      if (context.mounted) ref.invalidate(syncDekControllerProvider);
      toast.success(message: l10n.sync.keyEncryptionOff);
      return true;
    case .encrypt:
      final dek = (await SyncKeyManager.loadDek())!;
      try {
        await RemoteLease.protect(backend, () async {
          if (!await SyncKeyManager.claimRemoteKeyfile(backend, keyfile!)) {
            throw SyncKeyConflictException(l10n.sync.errKeyConflict);
          }
        });
      } catch (e) {
        toast.error(message: l10n.sync.keyWriteFailed(error: '$e'));
        return false;
      }
      SyncKeyManager.clearKeyConflict(id);
      if (!context.mounted) return false;
      return _encryptCloud(context, backend, dek);
  }
}

enum _AdoptOutcome { unlocked, cancelled, reset }

Future<_AdoptOutcome> _adoptRemoteKey({
  required BuildContext context,
  required WidgetRef ref,
  required IRemoteSyncBackend backend,
  required SyncKeyfile keyfile,
  required String passphrase,
}) async {
  List<int>? unwrapped;
  try {
    unwrapped = await SyncKeyManager.unwrapDek(
      keyfile: keyfile,
      passphrase: passphrase,
    );
  } catch (_) {
    unwrapped = null;
  }

  if (unwrapped != null) {
    Uint8List? manifestBytes;
    try {
      manifestBytes = await backend.readObject(SyncKeys.manifestPath);
    } catch (e) {
      if (context.mounted) {
        toast.error(message: l10n.sync.keyRemoteProbeFailed(error: '$e'));
      }
      return .cancelled;
    }
    var usable = true;
    if (manifestBytes != null && SyncCipher.isCipherText(manifestBytes)) {
      try {
        await SyncCipher.withKey(unwrapped).decode(manifestBytes);
      } catch (_) {
        usable = false;
      }
    }
    if (usable) {
      await SyncKeyManager.installKey(
        dek: unwrapped,
        keyfile: keyfile,
        backendId: backend.persistentBackendId,
        configured: await configuredCloudBackendIds(),
      );
      if (context.mounted) ref.invalidate(syncDekControllerProvider);
      if (context.mounted) toast.success(message: l10n.sync.keyUnlocked);
      return .unlocked;
    }
  }

  if (!context.mounted) return .cancelled;
  final wantsReset = await MAlert.confirm(
    context,
    title: l10n.sync.keyRemoteMismatchTitle,
    message: l10n.sync.keyRemoteMismatchMessage,
    confirmLabel: l10n.sync.keyResetAction,
    barrierDismissible: false,
  );
  if (!wantsReset || !context.mounted) return .cancelled;
  return await confirmRemoteReset(context) ? .reset : .cancelled;
}

Future<bool> confirmRemoteReset(BuildContext context) {
  return MAlert.confirm(
    context,
    title: l10n.sync.keyResetTitle,
    message: l10n.sync.keyResetMessage,
    icon: LucideIcons.rotateCcw,
    isDestructive: true,
    confirmLabel: l10n.sync.keyResetConfirm,
    barrierDismissible: false,
  );
}

Future<bool> resetRemote({
  required BuildContext context,
  required WidgetRef ref,
  required IRemoteSyncBackend backend,
  required String? passphrase,
}) async {
  if (!await AppAuth.verify(context, .syncCloudReset) || !context.mounted) {
    return false;
  }
  final configured = await configuredCloudBackendIds();
  if (!context.mounted) return false;
  final result = await _showProgress<RemoteWipeReport>(
    context,
    title: l10n.sync.keyWiping,
    start: (onProgress) => RemoteWipe.run(
      backend,
      passphrase: passphrase,
      configured: configured,
      onProgress: onProgress,
    ),
  );
  if (context.mounted) ref.invalidate(syncDekControllerProvider);
  final report = result?.value;
  if (report == null) {
    toast.error(message: l10n.sync.keyWipeFailed(error: '${result?.error}'));
    return false;
  }
  if (report.failed > 0) {
    toast.error(message: l10n.sync.keyWipePartial(failed: report.failed));
  } else {
    toast.success(message: l10n.sync.keyWiped(count: report.deleted));
  }
  return true;
}

Future<bool> _remoteExists(IRemoteSyncBackend backend) async {
  try {
    return await backend.readObject(SyncKeys.manifestPath) != null;
  } catch (_) {
    return true;
  }
}

Future<ReCipherReport?> _runWithProgress(
  BuildContext context, {
  required IRemoteSyncBackend backend,
  required SyncCipher from,
  required SyncCipher to,
}) async {
  final result = await _showProgress<ReCipherReport?>(
    context,
    title: l10n.sync.keyProcessing,
    start: (onProgress) =>
        CloudReCipher(backend).run(from: from, to: to, onProgress: onProgress),
  );

  if (result == null) return null;
  if (result.error != null) {
    if (context.mounted) {
      toast.error(
        message: l10n.sync.keyReCipherFailed(error: '${result.error}'),
      );
    }
    return null;
  }
  if (result.value == null) {
    if (context.mounted) toast.info(message: l10n.sync.keyRemoteEmpty);
  }
  return result.value;
}

Future<_ProgressResult<T>?> _showProgress<T>(
  BuildContext context, {
  required String title,
  required Future<T> Function(ReCipherProgress onProgress) start,
}) => showDialog<_ProgressResult<T>>(
  context: context,
  barrierDismissible: false,
  useRootNavigator: true,
  builder: (_) => _ProgressDialog<T>(title: title, start: start),
);

class _ProgressDialog<T> extends StatefulWidget {
  final String title;
  final Future<T> Function(ReCipherProgress onProgress) start;

  const _ProgressDialog({required this.title, required this.start});

  @override
  State<_ProgressDialog<T>> createState() => _ProgressDialogState<T>();
}

class _ProgressDialogState<T> extends State<_ProgressDialog<T>> {
  int _done = 0;
  int _total = 0;
  String _label = l10n.sync.keyPreparing;

  @override
  void initState() {
    super.initState();
    widget
        .start((done, total, label) {
          if (!mounted) return;
          setState(() {
            _done = done;
            _total = total;
            _label = label;
          });
        })
        .then((value) {
          if (!mounted) return;
          Navigator.of(context).pop(_ProgressResult<T>(value: value));
        })
        .catchError((Object e) {
          if (!mounted) return;
          final msg = e is SyncException ? e.message : e.toString();
          Navigator.of(context).pop(_ProgressResult<T>(error: msg));
        });
  }

  @override
  Widget build(BuildContext context) {
    final ratio = _total == 0 ? null : (_done / _total).clamp(0.0, 1.0);
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            LinearProgressIndicator(value: ratio),
            const SizedBox(height: 12),
            Text(
              '$_done / ${_total == 0 ? '?' : _total} · $_label',
              maxLines: 1,
              overflow: .ellipsis,
              style: context.theme.typography.bodySmall.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressResult<T> {
  final T? value;
  final String? error;
  const _ProgressResult({this.value, this.error});
}
