import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_sync/src/application/re_cipher.dart';
import 'package:moodiary_sync/src/application/user_key_controller.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_key_manager.dart';
import 'package:moodiary_sync/src/data/sync_registry.dart';
import 'package:mui/mui.dart';

/// 加密开关 / 改密码的「准备—确认—执行」编排（信封加密）：
///
/// - **开启加密**（无 DEK → 设密码）：生成随机 DEK → 写 keyfile（先落远端 +
///   本机，keyfile 即提交点）→ 存 DEK → 有远端数据则重加密（中断可重跑，已是
///   目标编码的对象自动跳过）；
/// - **改密码**（有 DEK → 换密码）：用新密码重包 DEK、重写 keys.json 单对象，
///   **数据零重写**；其它已配置后端记入待上传清单，下次同步补传；
/// - **关闭加密**（有 DEK → 清空）：远端解密回明文 → 删 keys.json → 清本机 DEK。
///
/// 返回 true = 已应用，false = 取消或失败。
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
    backend = .get();
  } catch (_) {
    backend = null;
  }
  final backendReady = backend != null && backend.isReady;

  // ── 改密码：重包 keyfile，数据零重写 ──
  if (dek != null && target != null) {
    final keyfile = await SyncKeyManager.wrapDek(dek: dek, passphrase: target);
    SyncKeyManager.cacheKeyfile(keyfile);
    // 所有已配置后端都需要新信封；活跃后端立即写，其余（含写失败的）走补传清单。
    await SyncKeyManager.markPendingUpload(configuredCloudBackendIds());
    if (backendReady) {
      try {
        await SyncKeyManager.writeRemoteKeyfile(backend, keyfile);
        final id = backend.persistentBackendId;
        if (id != null) await SyncKeyManager.clearPendingUpload(id);
      } catch (_) {
        // 保留在待上传清单，下次同步补传。
      }
    }
    if (context.mounted) {
      toast.success(message: l10n.sync.keyChanged);
    }
    return true;
  }

  // ── 开启加密 ──
  if (dek == null && target != null) {
    bool hasRemote = false;
    if (backendReady) {
      try {
        final bytes = await backend.readObject(SyncKeys.manifestPath);
        hasRemote = bytes != null && bytes.isNotEmpty;
      } catch (_) {
        hasRemote = false;
      }
    }

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
    // keyfile 先行（提交点）：远端一旦有 keys.json，任何设备都能凭密码解包，
    // 之后的重加密中断也可恢复。
    await SyncKeyManager.markPendingUpload(configuredCloudBackendIds());
    if (backendReady) {
      try {
        await SyncKeyManager.writeRemoteKeyfile(backend, keyfile);
        final id = backend.persistentBackendId;
        if (id != null) await SyncKeyManager.clearPendingUpload(id);
      } catch (e) {
        if (context.mounted) {
          toast.error(message: l10n.sync.keyWriteFailed(error: '$e'));
        }
        return false;
      }
    }
    await SyncKeyManager.storeDek(newDek);
    SyncKeyManager.cacheKeyfile(keyfile);
    ref.invalidate(syncDekControllerProvider);

    if (hasRemote) {
      if (!context.mounted) return true;
      final report = await _runWithProgress(
        context,
        // hasRemote 为真必然经过了 backendReady 探测。
        backend: backend!,
        from: .plaintext,
        to: .withKey(newDek),
      );
      if (report != null && context.mounted) {
        toast.success(message: l10n.sync.keyCloudEncrypted(report: report));
      }
    } else if (context.mounted) {
      toast.success(message: l10n.sync.keyEncryptionOn);
    }
    return true;
  }

  // ── 关闭加密（dek != null && target == null） ──
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
    // 远端为空（report null 且无错误）也继续关闭；真失败在 _runWithProgress 内已提示并返回 null——
    // 为避免半解密状态下丢 DEK，报错时不清本机密钥。
    if (report == null) {
      final stillHasRemote = await _remoteExists(backend);
      if (stillHasRemote) return false;
    }
    try {
      await SyncKeyManager.deleteRemoteKeyfile(backend);
    } catch (_) {
      // 删除失败只留残留文件：无数据可解，无害。
    }
  }
  await SyncKeyManager.clearDek();
  ref.invalidate(syncDekControllerProvider);
  if (context.mounted) toast.success(message: l10n.sync.keyEncryptionOff);
  return true;
}

Future<bool> _remoteExists(IRemoteSyncBackend backend) async {
  try {
    final bytes = await backend.readObject(SyncKeys.manifestPath);
    return bytes != null && bytes.isNotEmpty;
  } catch (_) {
    return true; // 探测失败按「有远端」保守处理
  }
}

Future<ReCipherReport?> _runWithProgress(
  BuildContext context, {
  required IRemoteSyncBackend backend,
  required SyncCipher from,
  required SyncCipher to,
}) async {
  // work + 进度 + pop 全收拢进 [_RecipherDialog]，用它自己的 context pop：
  // 否则从外部 context 反向 pop 会越过 go_router 上层路由，触发
  // "Future already completed"。
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
