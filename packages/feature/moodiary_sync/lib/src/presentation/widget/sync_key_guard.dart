import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_sync/src/application/user_key_controller.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/sync.dart';

/// 同步前的密钥前置守卫：远端已加密而本地密钥缺失或不匹配时，弹框引导输入并
/// 用远端 manifest 实测解密验证，通过并保存后才放行。返回 true = 可继续同步
/// （后端未配置 / 远端为空 / 远端明文 / 本地密钥可解 / 远端探测失败 均直接放行）。
///
/// 验证通过后直接保存密钥，**不走** `applyUserKeyChange` 的 re-cipher：远端本
/// 就是用该密钥加密的，无需重新封装；本地旧密钥若有只是配错，覆盖即可。
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
      // 密钥不匹配 → 走引导
    }
  }

  if (!context.mounted) return false;
  final entered = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _KeyEntryDialog(
      hasLocalKey: hasLocalKey,
      verify: (key) async {
        try {
          await SyncCipher(key).decode(bytes);
          return true;
        } catch (_) {
          return false;
        }
      },
    ),
  );
  if (entered == null) return false;

  await ref.read(userKeyControllerProvider.notifier).setKey(entered);
  toast.success(message: '密钥已配置');
  return true;
}

class _KeyEntryDialog extends StatefulWidget {
  /// true = 本地已有密钥但解不开远端（配错了）；false = 尚未配置密钥。
  final bool hasLocalKey;
  final Future<bool> Function(String key) verify;

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
      setState(() => _errorText = '请输入密钥');
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
        _errorText = '密钥不正确，无法解密远端数据';
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
                ? '当前设备的密钥无法解密远端数据。请输入与原设备一致的用户密钥，验证通过后开始同步。'
                : '远端数据使用用户密钥加密。请输入与原设备一致的用户密钥，验证通过后开始同步。',
            style: context.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: true,
            autofocus: true,
            enabled: !_verifying,
            decoration: InputDecoration(
              labelText: '用户密钥',
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
