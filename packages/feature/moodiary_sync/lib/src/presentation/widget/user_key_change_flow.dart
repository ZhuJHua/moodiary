import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_sync/src/application/user_key_controller.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/application/re_cipher.dart';
import 'package:moodiary_sync/src/data/sync.dart';

/// 用户密钥变更的「准备—确认—执行」编排：旧 / 新相同直接放行；无 cloud 数据
/// 直接落库；有 cloud 数据则弹确认框并跑 [CloudReCipher.run] 重新加密，**成功后
/// 才写入新密钥**（失败不写入）。返回 true = 密钥已应用，false = 取消或失败回滚。
Future<bool> applyUserKeyChange({
  required BuildContext context,
  required WidgetRef ref,
  required String? newKey,
}) async {
  final oldRaw = await MoodiarySecureKVs.userKey.get();
  final oldKey = (oldRaw == null || oldRaw.isEmpty) ? null : oldRaw;
  final target = (newKey == null || newKey.isEmpty) ? null : newKey;

  if (oldKey == target) return true;

  IRemoteSyncBackend? backend;
  try {
    backend = IRemoteSyncBackend.get();
  } catch (_) {
    backend = null;
  }

  bool hasRemote = false;
  if (backend != null && backend.isReady) {
    try {
      final bytes = await backend.readObject(SyncKeys.manifestPath);
      hasRemote = bytes != null && bytes.isNotEmpty;
    } catch (_) {
      // 网络异常 / 凭据失败 → 视作无远端，先在本地保存，下次 push 再适配。
      hasRemote = false;
    }
  }

  if (!hasRemote) {
    final ok = await _applyKeyOnly(ref, target);
    if (context.mounted) {
      if (ok) {
        toast.success(message: target == null ? '密钥已清空' : '密钥已保存');
      } else {
        toast.error(message: '密钥保存失败');
      }
    }
    return ok;
  }

  if (!context.mounted) return false;
  final confirmed = await _confirmRecipher(
    context,
    oldKey: oldKey,
    newKey: target,
  );
  if (confirmed != true) return false;

  if (!context.mounted) return false;
  final report = await _runWithProgress(
    context,
    backend: backend!,
    from: SyncCipher(oldKey),
    to: SyncCipher(target),
  );
  if (report == null) return false;

  final applied = await _applyKeyOnly(ref, target);
  if (applied && context.mounted) {
    toast.success(message: '云端已重新封装：${report.toString()}');
  }
  return applied;
}

Future<bool> _applyKeyOnly(WidgetRef ref, String? target) async {
  final controller = ref.read(userKeyControllerProvider.notifier);
  if (target == null) {
    await controller.clear();
    return true;
  }
  return controller.setKey(target);
}

Future<bool?> _confirmRecipher(
  BuildContext context, {
  required String? oldKey,
  required String? newKey,
}) {
  final String title;
  final String body;
  if (oldKey == null && newKey != null) {
    title = '加密云端已有数据';
    body =
        '检测到当前同步后端已存在数据。确认后会用新密钥重新加密云端的日记、分类与媒体文件。';
  } else if (oldKey != null && newKey != null) {
    title = '更换密钥';
    body = '云端数据当前用旧密钥加密。确认后会先用旧密钥解密、再用新密钥重新加密整份云端备份。';
  } else {
    title = '解密云端数据';
    body = '清空密钥后，云端的日记、分类与媒体文件会被解密回明文。确认要继续吗？';
  }
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('继续'),
        ),
      ],
    ),
  );
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
