import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_sync/src/application/user_key_controller.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_key_manager.dart';
import 'package:moodiary_sync/src/data/sync_keyfile.dart';
import 'package:moodiary_sync/src/data/sync_registry.dart';

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
      toast.error(
        message: '远端数据已加密但缺少密钥文件（keys.json），无法解密。请清空远端数据后重新上传。',
      );
    }
    return false;
  }

  if (!context.mounted) return false;
  List<int>? unwrappedDek;
  final entered = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _KeyEntryDialog(
      hasLocalKey: hasLocalKey,
      verify: (passphrase) async {
        try {
          final dek = await SyncKeyManager.unwrapDek(
            keyfile: keyfile!,
            passphrase: passphrase,
          );
          // 双保险：keyfile 解包成功后再实测解密 manifest（防 keyfile 与数据不配套）。
          await SyncCipher.withKey(dek).decode(bytes);
          unwrappedDek = dek;
          return true;
        } catch (_) {
          return false;
        }
      },
    ),
  );
  if (entered == null || unwrappedDek == null) return false;

  await SyncKeyManager.storeDek(unwrappedDek!);
  await SyncKeyManager.cacheKeyfile(keyfile);
  // 其余已配置后端也需要 keyfile（本后端已有，出清单）。
  await SyncKeyManager.markPendingUpload(configuredCloudBackendIds());
  final backendId = backend.persistentBackendId;
  if (backendId != null) await SyncKeyManager.clearPendingUpload(backendId);
  ref.invalidate(syncDekControllerProvider);
  toast.success(message: '密钥已配置');
  return true;
}

class _KeyEntryDialog extends StatefulWidget {
  /// true = 本地已有密钥但解不开远端（配错了）；false = 尚未配置密钥。
  final bool hasLocalKey;
  final Future<bool> Function(String passphrase) verify;

  const _KeyEntryDialog({required this.hasLocalKey, required this.verify});

  @override
  State<_KeyEntryDialog> createState() => _KeyEntryDialogState();
}

class _KeyEntryDialogState extends State<_KeyEntryDialog> {
  final _controller = TextEditingController();
  String? _errorText;
  bool _verifying = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final key = _controller.text.trim();
    if (key.isEmpty) {
      setState(() => _errorText = '请输入密码');
      return;
    }
    setState(() {
      _verifying = true;
      _errorText = null;
    });
    final ok = await widget.verify(key);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(key);
    } else {
      setState(() {
        _verifying = false;
        _errorText = '密码不正确，无法解密远端数据';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('远端备份已加密'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.hasLocalKey
                ? '当前设备的密钥无法解密远端数据。请输入与原设备一致的加密密码，验证通过后开始同步。'
                : '远端数据已加密。请输入与原设备一致的加密密码，验证通过后开始同步。',
            style: context.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: true,
            autofocus: true,
            enabled: !_verifying,
            decoration: InputDecoration(
              labelText: '加密密码',
              border: const OutlineInputBorder(),
              errorText: _errorText,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _verifying ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _verifying ? null : _submit,
          child: _verifying
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('验证并保存'),
        ),
      ],
    );
  }
}
