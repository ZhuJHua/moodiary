import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_sync/src/application/user_key_controller.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/application/re_cipher.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_key_manager.dart';
import 'package:moodiary_sync/src/data/sync_registry.dart';

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
    backend = IRemoteSyncBackend.get();
  } catch (_) {
    backend = null;
  }
  final backendReady = backend != null && backend.isReady;

  // ── 改密码：重包 keyfile，数据零重写 ──
  if (dek != null && target != null) {
    final keyfile = await SyncKeyManager.wrapDek(dek: dek, passphrase: target);
    await SyncKeyManager.cacheKeyfile(keyfile);
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
      toast.success(message: '密码已更换（数据密钥不变，云端无需重新加密）');
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
      final confirmed = await showMoodiaryConfirm(
        context,
        title: '加密云端已有数据',
        message: '检测到当前同步后端已存在数据。确认后会生成随机数据密钥并加密云端的日记、分类与媒体文件；该密钥由你的密码封装存放在云端。',
        confirmLabel: '继续',
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
          toast.error(message: '密钥文件写入云端失败，已取消：$e');
        }
        return false;
      }
    }
    await SyncKeyManager.storeDek(newDek);
    await SyncKeyManager.cacheKeyfile(keyfile);
    ref.invalidate(syncDekControllerProvider);

    if (hasRemote) {
      if (!context.mounted) return true;
      final report = await _runWithProgress(
        context,
        // hasRemote 为真必然经过了 backendReady 探测。
        backend: backend!,
        from: SyncCipher.plaintext,
        to: SyncCipher.withKey(newDek),
      );
      if (report != null && context.mounted) {
        toast.success(message: '云端已加密：$report');
      }
    } else if (context.mounted) {
      toast.success(message: '加密已开启');
    }
    return true;
  }

  // ── 关闭加密（dek != null && target == null） ──
  if (!context.mounted) return false;
  final confirmed = await showMoodiaryConfirm(
    context,
    title: '解密云端数据',
    message: '关闭加密后，云端的日记、分类与媒体文件会被解密回明文，密钥文件将被删除。确认要继续吗？',
    confirmLabel: '继续',
    barrierDismissible: false,
  );
  if (!confirmed) return false;

  if (backendReady) {
    if (!context.mounted) return false;
    final report = await _runWithProgress(
      context,
      backend: backend,
      from: SyncCipher.withKey(dek),
      to: SyncCipher.plaintext,
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
  if (context.mounted) toast.success(message: '加密已关闭');
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
          CloudReCipher(backend).run(from: from, to: to, onProgress: onProgress),
    ),
  );

  if (result == null) return null;
  if (result.error != null) {
    if (context.mounted) toast.error(message: '重新加密失败：${result.error}');
    return null;
  }
  if (result.report == null) {
    if (context.mounted) toast.info(message: '远端为空，仅保存本地密钥');
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
  String _label = '准备';

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
        title: const Text('正在处理云端数据'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: ratio),
            const SizedBox(height: 12),
            Text(
              '$_done / ${_total == 0 ? '?' : _total} · $_label',
              style: context.textTheme.bodySmall,
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
