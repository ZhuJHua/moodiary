import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_sync/src/application/re_cipher.dart';
import 'package:moodiary_sync/src/application/user_key_controller.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_key_manager.dart';
import 'package:moodiary_sync/src/data/sync_keyfile.dart';
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
      // 换了后端 / 指向了别人加密过的目录时，本机 DEK 未必是这份远端数据的 DEK。
      // 盲写会把远端信封换掉、令那些数据永久解不开——同 uploadPendingKeyfile 的判据。
      final check = await SyncKeyManager.checkRemoteKeyfile(backend);
      if (check == .conflict) {
        SyncKeyManager.markKeyConflict(backend.persistentBackendId);
        if (context.mounted) {
          toast.error(message: l10n.sync.keyChangedLocalOnly);
        }
        return true; // 本机密码已改；远端等用户解锁后再补传
      }
      if (check == .safe) {
        try {
          await SyncKeyManager.writeRemoteKeyfile(backend, keyfile);
          final id = backend.persistentBackendId;
          if (id != null) await SyncKeyManager.clearPendingUpload(id);
        } catch (_) {
          // 保留在待上传清单，下次同步补传。
        }
      }
    }
    if (context.mounted) {
      toast.success(message: l10n.sync.keyChanged);
    }
    return true;
  }

  // ── 开启加密 ──
  if (dek == null && target != null) {
    // 本机没有 DEK 只说明这台设备没配过，**不代表远端没加密**（换机 / 重装 /
    // 钥匙串被清都会走到这里，而界面显示的正是「未开启」）。此时新建一把 DEK 并
    // 写出去，会把远端唯一的信封换掉，用旧 DEK 加密的日记与媒体就永久解不开了。
    // 所以先探远端信封：有信封就改走「用这个密码解锁已有密钥」。
    SyncKeyfile? remoteKeyfile;
    Uint8List? remoteManifest;
    if (backendReady) {
      try {
        remoteKeyfile = await SyncKeyManager.readRemoteKeyfile(backend);
        remoteManifest = await backend.readObject(SyncKeys.manifestPath);
      } catch (e) {
        // 探不出来就不动远端 —— 按「远端没有信封」继续会正好踩中上面那颗雷。
        if (context.mounted) {
          toast.error(message: l10n.sync.keyRemoteProbeFailed(error: '$e'));
        }
        return false;
      }
    }

    // 有信封、但远端数据其实是明文（关闭加密时删 keys.json 失败会留下这种残留）：
    // 这份信封既没有密文要保护、也没有任何密码解得开它。当它不存在，照常走下面的
    // 「明文远端重加密」；否则用户会被引导去丢弃一份完全健康、根本不需要密钥的数据。
    //
    // 但「残留」这个结论只有一份**读得到且非空**的明文 manifest 能证明。manifest
    // 读不到（远端还没写过 / 上次 push 传完媒体就中断）或读到 0 字节（PUT 被截断）
    // 时，远端很可能正握着一批用这个信封的 DEK 加密的对象——此刻把信封判成残留、
    // 转头生成新 DEK 覆盖它，那批密文就永久解不开。不知道就当它在，走解锁流程。
    // 判据与引擎侧 [SyncKeyManager.checkRemoteKeyfile] 保持一致。
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
        // remoteKeyfile 非空必然经过了 backendReady 探测。
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
          // 用户已二次确认放弃远端密文：清掉信封与清单，下次 push 按空远端重建。
          if (!context.mounted) return false;
          if (!await _discardRemoteEnvelope(context, backend)) return false;
      }
    }

    // 刚丢弃过信封的远端按空处理：manifest 已删，重加密无对象可跑。
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
    // keyfile 先行（提交点）：远端一旦有 keys.json，任何设备都能凭密码解包，
    // 之后的重加密中断也可恢复。
    await SyncKeyManager.markPendingUpload(configuredCloudBackendIds());
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
        // 失败的对象原样留明文。不致命（codec 按 magic 头自动识别，读得回来），
        // 但用户得知道云端还有一批没加密。
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
      // 读不到 manifest ≠ 远端什么都没有：首次 push 是先传媒体、最后才写 manifest，
      // 中断就正好留下「一批 DEK 密文媒体 + 没有清单」。DEK 一清，它们就成了没有任何
      // 密钥的密文，而下次 push 的 stat 还会把它们判成「远端已存在」跳过，永不重传。
      // 先让远端媒体失信，把不可逆的失钥降级成一次重传。
      SyncKeyManager.markForceMediaReupload(backend.persistentBackendId);
    } else if (report.failed > 0) {
      // CloudReCipher 是逐条计数、不中断的：失败的对象原样保留 AES 密文，而
      // manifest 已按明文写出。此刻若照常删 keys.json + 清 DEK，那些对象就成了
      // **没有任何密钥的密文**，而且没有自愈路径 —— push 侧 LWW 比对走 skip 不会
      // 重传覆盖，pull 侧解密失败又被吞掉。宁可保持加密开启，让用户重试。
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
      // 删除失败只留残留信封。开启加密那条路径已经会先判远端数据是不是密文
      // （见 _adoptRemoteKey 的调用点），残留信封不会再把明文远端误导向丢弃。
    }
  }
  await SyncKeyManager.clearDek();
  if (context.mounted) ref.invalidate(syncDekControllerProvider);
  if (context.mounted) toast.success(message: l10n.sync.keyEncryptionOff);
  return true;
}

/// [_adoptRemoteKey] 的去向。
enum _AdoptOutcome {
  /// 密码解开了远端信封，DEK 已采用并落本机 —— 整个「开启加密」到此结束。
  unlocked,

  /// 用户放弃操作，远端分毫未动。
  cancelled,

  /// 用户已二次确认「丢弃远端加密数据、用新密码重新开始」。
  discardRemote,
}

/// 远端已有信封时的正确动作：不是新建密钥，而是**用用户输入的密码解开远端已有的
/// DEK 并采用它**——远端数据本就是那把 DEK 加密的，换一把只会让它们全部作废。
///
/// 密码打不开时给用户一条明确的出路（否则忘了密码就只能自己去网盘手删目录，更容易
/// 删错东西），但要连过两道确认。
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
    unwrapped = null; // 密码不对
  }

  if (unwrapped != null) {
    // 双保险：信封解得开不等于它与远端数据配套（信封被单独换过就会这样）。
    Uint8List? manifestBytes;
    try {
      manifestBytes = await backend.readObject(SyncKeys.manifestPath);
    } catch (e) {
      // 网络故障不该把用户推向「丢弃远端数据」，原地中止。
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
      // 其余已配置后端也需要这份信封（本后端已有，出清单）。
      await SyncKeyManager.markPendingUpload(configuredCloudBackendIds());
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

/// 丢弃远端密文：删掉 manifest 与信封，下次 push 即按空远端重建并用新密钥加密。
/// 旧密文 JSON 成为无人引用的垃圾（同名对象下次 push 无条件覆盖）；媒体不会被
/// 覆盖而是走存在性跳过，所以另挂强制重传标记，否则它们会被确认进新 manifest。
Future<bool> _discardRemoteEnvelope(
  BuildContext context,
  IRemoteSyncBackend backend,
) async {
  try {
    // 顺序要紧：先删 manifest 再删信封。反过来一旦第二步失败，远端就成了「密文
    // 对象 + 没有信封」——没有任何密码能再打开它，而用户看到的却是「已取消」。
    await backend.deleteObject(SyncKeys.manifestPath);
    await SyncKeyManager.deleteRemoteKeyfile(backend);
  } catch (e) {
    if (context.mounted) {
      toast.error(message: l10n.sync.keyDiscardFailed(error: '$e'));
    }
    return false;
  }
  SyncKeyManager.clearKeyConflict(backend.persistentBackendId);
  // 旧密文媒体还留在远端且与本机同名：不强制重传，push 的 stat 兜底会把它们当作
  // 「远端已存在」跳过、写进新 manifest，而能解开它们的信封刚被删掉。
  SyncKeyManager.markForceMediaReupload(backend.persistentBackendId);
  return true;
}

Future<bool> _remoteExists(IRemoteSyncBackend backend) async {
  try {
    // 0 字节 = 清单被截断，**存在但坏了**，不是不存在：远端多半还压着一批密文。
    return await backend.readObject(SyncKeys.manifestPath) != null;
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
