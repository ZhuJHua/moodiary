import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_sync/src/application/user_key_controller.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_key_manager.dart';
import 'package:moodiary_sync/src/data/sync_keyfile.dart';
import 'package:moodiary_sync/src/data/sync_registry.dart';
import 'package:moodiary_ui/moodiary_ui.dart';

/// 同步前的密钥前置守卫：远端已加密而本地 DEK 缺失或不匹配时，弹框引导输入
/// 密码，用远端 keys.json 解包出 DEK、再实测解密 manifest 验证，通过并保存后
/// 才放行。返回 true = 可继续同步（后端未配置 / 远端为空 / 远端明文 / 本地
/// DEK 可解 / 远端探测失败 均直接放行）。
///
/// 验证通过后直接保存 DEK，不做任何重新封装：远端本就是这把 DEK 加密的。
Future<bool> ensureSyncKeyReady({
  required BuildContext context,
  required WidgetRef ref,
  required IRemoteSyncBackend backend,
}) async {
  if (!backend.isReady) return true;

  Uint8List? manifestBytes;
  try {
    manifestBytes = await backend.readObject(SyncKeys.manifestPath);
  } catch (_) {
    return true; // 远端不可达：交给常规同步错误流程
  }
  if (manifestBytes == null || !SyncCipher.isCipherText(manifestBytes)) {
    return true;
  }

  final bytes = manifestBytes;
  final current = await SyncCipher.current();
  var hasLocalKey = false;
  if (current.encrypted) {
    hasLocalKey = true;
    try {
      await current.decode(bytes);
      return true;
    } on SyncException {
      // DEK 不匹配 → 走引导
    }
  }

  // 解包所需的 keyfile：读取失败（网络）放行给常规错误流程；确认缺失则明确报错
  // —— 对象加密而 keys.json 没了，没有任何密码能解开。
  final SyncKeyfile? keyfile;
  try {
    keyfile = await SyncKeyManager.readRemoteKeyfile(backend);
  } on SyncException catch (e) {
    if (context.mounted) toast.error(message: e.message);
    return false; // keyfile 存在但损坏 / 版本不兼容
  } catch (_) {
    return true;
  }
  if (keyfile == null) {
    if (context.mounted) {
      toast.error(message: l10n.sync.keyGuardMissing);
    }
    return false;
  }

  if (!context.mounted) return false;
  List<int>? unwrappedDek;
  final entered = await MAlert.prompt(
    context,
    title: l10n.sync.keyGuardTitle,
    message: hasLocalKey
        ? l10n.sync.keyGuardMessageMismatch
        : l10n.sync.keyGuardMessage,
    hintText: l10n.sync.keyGuardHint,
    confirmLabel: l10n.sync.keyGuardConfirm,
    obscureText: true,
    // 保持 trim：旧实现校验与落盘用的都是 trim 后的串，改成原文会让首尾带空格的
    // 密码解不开已有的 keyfile。
    barrierDismissible: false,
    validator: (value) => value.isEmpty ? l10n.sync.keyNeedPassword : null,
    onSubmit: (passphrase) async {
      try {
        final dek = await SyncKeyManager.unwrapDek(
          keyfile: keyfile!,
          passphrase: passphrase,
        );
        // 双保险：keyfile 解包成功后再实测解密 manifest（防 keyfile 与数据不配套）。
        await SyncCipher.withKey(dek).decode(bytes);
        unwrappedDek = dek;
        return null;
      } catch (_) {
        return l10n.sync.keyGuardWrong;
      }
    },
  );
  if (entered == null || unwrappedDek == null) return false;

  await SyncKeyManager.storeDek(unwrappedDek!);
  await SyncKeyManager.cacheKeyfile(keyfile);
  // 其余已配置后端也需要 keyfile（本后端已有，出清单）。
  await SyncKeyManager.markPendingUpload(configuredCloudBackendIds());
  final backendId = backend.persistentBackendId;
  if (backendId != null) await SyncKeyManager.clearPendingUpload(backendId);
  ref.invalidate(syncDekControllerProvider);
  toast.success(message: l10n.sync.keyConfigured);
  return true;
}
