import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_sync/src/application/user_key_controller.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_key_manager.dart';
import 'package:moodiary_sync/src/data/sync_keyfile.dart';
import 'package:moodiary_sync/src/data/sync_provider_scope.dart';
import 'package:moodiary_sync/src/presentation/widget/user_key_change_flow.dart';
import 'package:moodiary_sync/src/presentation/widget/user_key_tile.dart';
import 'package:mui/mui.dart';

Future<bool> ensureSyncKeyReady({
  required BuildContext context,
  required WidgetRef ref,
  required IRemoteSyncBackend backend,
}) async {
  if (!await backend.isReady()) return true;

  Uint8List? manifestBytes;
  try {
    manifestBytes = await backend.readObject(SyncKeys.manifestPath);
  } catch (_) {
    return true;
  }
  if (manifestBytes == null || !SyncCipher.isCipherText(manifestBytes)) {
    final bool decrypted;
    try {
      decrypted =
          manifestBytes != null &&
          await SyncKeyManager.remoteDecryptedElsewhere(backend, manifestBytes);
    } catch (_) {
      return true;
    }
    if (decrypted) {
      if (!context.mounted) return false;
      return resolveDecryptedRemote(
        context: context,
        ref: ref,
        backend: backend,
      );
    }
    SyncKeyManager.clearKeyConflict(backend.persistentBackendId);
    return true;
  }

  final bytes = manifestBytes;
  final current = await SyncCipher.current();
  var hasLocalKey = false;
  if (current.encrypted) {
    hasLocalKey = true;
    try {
      await current.decode(bytes);
      SyncKeyManager.clearKeyConflict(backend.persistentBackendId);
      return true;
    } on SyncException {
      // 本地密钥解不开清单 = 换过密钥，往下走 keyfile 分支
    }
  }

  final SyncKeyfile? keyfile;
  try {
    keyfile = await SyncKeyManager.readRemoteKeyfile(backend);
  } on SyncException catch (e) {
    if (context.mounted) toast.error(message: e.message);
    return false;
  } catch (_) {
    return true;
  }
  if (keyfile == null) {
    if (!context.mounted) return false;
    final reset = await MAlert.confirm(
      context,
      title: l10n.sync.keyMissingTitle,
      message: l10n.sync.keyGuardMissing,
      icon: LucideIcons.triangleAlert,
      isDestructive: true,
      confirmLabel: l10n.sync.keyResetAction,
    );
    if (reset && context.mounted) {
      await resetAndOfferNewKey(context: context, ref: ref, backend: backend);
    }
    return false;
  }

  SyncKeyManager.markKeyConflict(backend.persistentBackendId);

  if (!context.mounted) return false;
  List<int>? unwrappedDek;
  var forgot = false;
  final entered = await MAlert.prompt(
    context,
    title: l10n.sync.keyGuardTitle,
    message: hasLocalKey
        ? l10n.sync.keyGuardMessageMismatch
        : l10n.sync.keyGuardMessage,
    hintText: l10n.sync.keyGuardHint,
    confirmLabel: l10n.sync.keyGuardConfirm,
    obscureText: true,
    // keyfile 按 trim 后的 passphrase 生成，改成原文会让带首尾空格的密码解不开
    barrierDismissible: false,
    validator: (value) => value.isEmpty ? l10n.sync.keyNeedPassword : null,
    footer: Builder(
      builder: (ctx) => Align(
        alignment: .centerRight,
        child: MInkWell.fade(
          onTap: () {
            forgot = true;
            Navigator.of(ctx).pop();
          },
          child: Padding(
            padding: const .fromLTRB(8, 6, 2, 6),
            child: Text(
              l10n.sync.keyForgot,
              style: ctx.theme.typography.labelMedium.onSurfaceVariant,
            ),
          ),
        ),
      ),
    ),
    onSubmit: (passphrase) async {
      try {
        final dek = await SyncKeyManager.unwrapDek(
          keyfile: keyfile!,
          passphrase: passphrase,
        );
        await SyncCipher.withKey(dek).decode(bytes);
        unwrappedDek = dek;
        return null;
      } catch (_) {
        return l10n.sync.keyGuardWrong;
      }
    },
  );
  if (forgot) {
    if (context.mounted) {
      await resetAndOfferNewKey(context: context, ref: ref, backend: backend);
    }
    return false;
  }
  if (entered == null || unwrappedDek == null) return false;

  await SyncKeyManager.installKey(
    dek: unwrappedDek!,
    keyfile: keyfile,
    backendId: backend.persistentBackendId,
    configured: await configuredCloudBackendIds(),
  );
  if (context.mounted) ref.invalidate(syncDekControllerProvider);
  toast.success(message: l10n.sync.keyConfigured);
  return true;
}
