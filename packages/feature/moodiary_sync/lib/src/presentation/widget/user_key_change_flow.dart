import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_sync/src/application/re_cipher.dart';
import 'package:moodiary_sync/src/application/user_key_controller.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_key_manager.dart';
import 'package:moodiary_sync/src/data/sync_keyfile.dart';
import 'package:moodiary_sync/src/data/sync_provider_scope.dart';
import 'package:mui/mui.dart';

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

  IRemoteSyncBackend? backend;
  try {
    backend = getIt<IRemoteSyncBackend>();
  } catch (_) {
    backend = null;
  }
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
        } catch (_) {
        }
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
    if (remoteKeyfile != null && remoteIsPlaintext) {
      remoteKeyfile = null;
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
        case .discardRemote:
          if (!context.mounted) return false;
          if (!await _discardRemoteEnvelope(context, backend)) return false;
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
    await SyncKeyManager.markPendingUpload(await configuredCloudBackendIds());
    if (backendReady) {
      try {
        await SyncKeyManager.writeRemoteKeyfile(backend, keyfile);
        final id = backend.persistentBackendId;
        if (id != null) {
          await SyncKeyManager.clearPendingUpload(id);
          SyncKeyManager.clearKeyConflict(id);
        }
      } catch (e) {
        if (context.mounted) {
          toast.error(message: l10n.sync.keyWriteFailed(error: '$e'));
        }
        return false;
      }
    }
    await SyncKeyManager.storeDek(newDek);
    SyncKeyManager.cacheKeyfile(keyfile);
    if (context.mounted) ref.invalidate(syncDekControllerProvider);

    if (hasRemote) {
      if (!context.mounted) return true;
      final report = await _runWithProgress(
        context,
        backend: backend,
        from: .plaintext,
        to: .withKey(newDek),
      );
      if (report != null && report.failed > 0) {
        if (context.mounted) {
          toast.error(
            message: l10n.sync.keyEncryptPartial(failed: report.failed),
          );
        }
      } else if (report != null && context.mounted) {
        toast.success(message: l10n.sync.keyCloudEncrypted(report: report));
      }
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
  if (!confirmed) return false;

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
    } catch (_) {
    }
  }
  await SyncKeyManager.clearDek();
  if (context.mounted) ref.invalidate(syncDekControllerProvider);
  if (context.mounted) toast.success(message: l10n.sync.keyEncryptionOff);
  return true;
}

enum _AdoptOutcome {
  unlocked,

  cancelled,

  discardRemote,
}

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
      await SyncKeyManager.storeDek(unwrapped);
      SyncKeyManager.cacheKeyfile(keyfile);
      await SyncKeyManager.markPendingUpload(await configuredCloudBackendIds());
      final id = backend.persistentBackendId;
      if (id != null) {
        await SyncKeyManager.clearPendingUpload(id);
        SyncKeyManager.clearKeyConflict(id);
      }
      if (context.mounted) ref.invalidate(syncDekControllerProvider);
      if (context.mounted) toast.success(message: l10n.sync.keyUnlocked);
      return .unlocked;
    }
  }

  if (!context.mounted) return .cancelled;
  final wantsDiscard = await MAlert.confirm(
    context,
    title: l10n.sync.keyRemoteMismatchTitle,
    message: l10n.sync.keyRemoteMismatchMessage,
    confirmLabel: l10n.sync.keyDiscardRemote,
    barrierDismissible: false,
  );
  if (!wantsDiscard || !context.mounted) return .cancelled;

  final confirmed = await MAlert.confirm(
    context,
    title: l10n.sync.keyDiscardTitle,
    message: l10n.sync.keyDiscardMessage,
    confirmLabel: l10n.sync.keyDiscardConfirm,
    barrierDismissible: false,
  );
  return confirmed ? .discardRemote : .cancelled;
}

Future<bool> _discardRemoteEnvelope(
  BuildContext context,
  IRemoteSyncBackend backend,
) async {
  try {
    await backend.deleteObject(SyncKeys.manifestPath);
    await SyncKeyManager.deleteRemoteKeyfile(backend);
  } catch (e) {
    if (context.mounted) {
      toast.error(message: l10n.sync.keyDiscardFailed(error: '$e'));
    }
    return false;
  }
  SyncKeyManager.clearKeyConflict(backend.persistentBackendId);
  SyncKeyManager.markForceMediaReupload(backend.persistentBackendId);
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
  final result = await showDialog<_RecipherResult>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) => _RecipherDialog(
      start: (onProgress) =>
          CloudReCipher(backend)
              .run(from: from, to: to, onProgress: onProgress),
    ),
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
  if (result.report == null) {
    if (context.mounted) toast.info(message: l10n.sync.keyRemoteEmpty);
  }
  return result.report;
}

class _RecipherDialog extends StatefulWidget {
  final Future<ReCipherReport?> Function(ReCipherProgress onProgress) start;

  const _RecipherDialog({required this.start});

  @override
  State<_RecipherDialog> createState() => _RecipherDialogState();
}

class _RecipherDialogState extends State<_RecipherDialog> {
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
        .then((report) {
          if (!mounted) return;
          Navigator.of(context).pop(_RecipherResult(report: report));
        })
        .catchError((Object e) {
          if (!mounted) return;
          final msg = e is SyncException ? e.message : e.toString();
          Navigator.of(context).pop(_RecipherResult(error: msg));
        });
  }

  @override
  Widget build(BuildContext context) {
    final ratio = _total == 0 ? null : (_done / _total).clamp(0.0, 1.0);
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(context.l10n.sync.keyProcessing),
        content: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            LinearProgressIndicator(value: ratio),
            const SizedBox(height: 12),
            Text(
              '$_done / ${_total == 0 ? '?' : _total} · $_label',
              style: context.theme.typography.bodySmall.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipherResult {
  final ReCipherReport? report;
  final String? error;
  const _RecipherResult({this.report, this.error});
}
