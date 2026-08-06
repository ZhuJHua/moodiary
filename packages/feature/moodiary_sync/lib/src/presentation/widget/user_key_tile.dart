import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_sync/src/application/user_key_controller.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_key_manager.dart';
import 'package:moodiary_sync/src/presentation/widget/user_key_change_flow.dart';

/// 端到端加密设置项。**加密语义**：设置密码即开启加密（生成随机数据密钥 DEK，
/// 密码只用来封装它）；清除即关闭加密。
class UserKeyTile extends ConsumerWidget {
  final bool isFirst;
  final bool isLast;

  const UserKeyTile({super.key, this.isFirst = false, this.isLast = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(syncDekControllerProvider);
    final dekB64 = async.maybeWhen(data: (v) => v, orElse: () => null);
    final hasKey = dekB64 != null && dekB64.isNotEmpty;
    final scheme = context.colorScheme;

    return SettingListTile(
      isFirst: isFirst,
      isLast: isLast,
      title: '端到端加密',
      leading: const Icon(LucideIcons.key),
      subtitle: hasKey ? '已开启' : '未开启',
      trailing: IconButton.filled(
        tooltip: '管理加密',
        icon: Icon(LucideIcons.settings, color: scheme.onPrimary),
        onPressed: () => _showKeyManageSheet(context, ref, hasKey),
      ),
    );
  }

  Future<void> _showKeyManageSheet(
    BuildContext context,
    WidgetRef ref,
    bool hasExistingKey,
  ) async {
    await showMoodiarySheet<void>(
      context,
      builder: (ctx) => _KeyManageSheet(
        hasExistingKey: hasExistingKey,
        onSubmit: (newKey) async {
          Navigator.of(ctx).pop();
          await applyUserKeyChange(context: context, ref: ref, newKey: newKey);
        },
        onRemove: hasExistingKey
            ? () async {
                Navigator.of(ctx).pop();
                await applyUserKeyChange(
                  context: context,
                  ref: ref,
                  newKey: null,
                );
              }
            : null,
      ),
    );
  }
}

class _KeyManageSheet extends StatefulWidget {
  final bool hasExistingKey;
  final void Function(String newKey) onSubmit;
  final VoidCallback? onRemove;

  const _KeyManageSheet({
    required this.hasExistingKey,
    required this.onSubmit,
    this.onRemove,
  });

  @override
  State<_KeyManageSheet> createState() => _KeyManageSheetState();
}

class _KeyManageSheetState extends State<_KeyManageSheet> {
  final _currentKeyController = TextEditingController();
  final _newKeyController = TextEditingController();
  final _confirmKeyController = TextEditingController();

  bool _currentVerified = false;
  bool _verifying = false;
  String? _currentError;
  String? _newError;
  String? _confirmError;

  @override
  void initState() {
    super.initState();
    if (!widget.hasExistingKey) {
      _currentVerified = true;
    }
  }

  @override
  void dispose() {
    _currentKeyController.dispose();
    _newKeyController.dispose();
    _confirmKeyController.dispose();
    super.dispose();
  }

  /// 校验当前密码：对着 keyfile（后端可达取远端，离线用本机缓存）解包 DEK
  /// 并与本机比对 —— 密码原文不落库，无从做字符串比较。
  Future<void> _verifyCurrent() async {
    if (_verifying) return;
    setState(() {
      _verifying = true;
      _currentError = null;
    });
    IRemoteSyncBackend? backend;
    try {
      backend = IRemoteSyncBackend.get();
    } catch (_) {
      backend = null;
    }
    final ok = await SyncKeyManager.verifyPassphrase(
      _currentKeyController.text.trim(),
      backend: backend,
    );
    if (!mounted) return;
    setState(() {
      _verifying = false;
      _currentVerified = ok;
      _currentError = ok ? null : '密码不正确';
    });
    if (ok) toast.success(message: '验证成功');
  }

  bool _validate() {
    final currentError = widget.hasExistingKey && !_currentVerified
        ? '请先验证当前密码'
        : null;
    final newError = _newKeyController.text.trim().isEmpty ? '请输入密码' : null;
    final confirmError = _confirmKeyController.text != _newKeyController.text
        ? '两次输入的密码不一致'
        : null;
    setState(() {
      _currentError = currentError;
      _newError = newError;
      _confirmError = confirmError;
    });
    return currentError == null && newError == null && confirmError == null;
  }

  /// 关闭加密须先验证当前密码，防止拿到已解锁设备者直接解除加密。
  void _remove() {
    if (!_currentVerified) {
      setState(() => _currentError = '请先验证当前密码');
      return;
    }
    widget.onRemove!();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return MoodiarySheetScaffold<void>(
      title: '加密管理',
      subtitle: widget.hasExistingKey ? '已开启' : '未开启',
      icon: LucideIcons.key,
      actions: [
        MoodiaryAction(label: context.l10n.cancel, enabled: !_verifying),
        MoodiaryAction(
          label: context.l10n.save,
          isPrimary: true,
          enabled: !_verifying,
          onPressed: () {
            if (_validate()) widget.onSubmit(_newKeyController.text.trim());
          },
        ),
      ],
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        spacing: 14,
        children: [
          if (widget.hasExistingKey)
            MoodiaryField(
              controller: _currentKeyController,
              label: '当前密码',
              errorText: _currentError,
              obscureText: true,
              enabled: !_verifying,
              onChanged: (_) {
                if (_currentVerified) setState(() => _currentVerified = false);
              },
              // 验证是这个字段自己的动作，放尾部槽位比另起一行按钮更贴。
              trailing: _currentVerified
                  ? Icon(LucideIcons.circleCheck, color: scheme.primary)
                  : IconButton(
                      tooltip: '验证',
                      icon: _verifying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(LucideIcons.badgeCheck, size: 18),
                      color: scheme.onSurfaceVariant,
                      visualDensity: .compact,
                      onPressed: _verifying ? null : _verifyCurrent,
                    ),
            ),
          MoodiaryField(
            controller: _newKeyController,
            label: widget.hasExistingKey ? '新密码' : '加密密码',
            errorText: _newError,
            obscureText: true,
            enabled: !_verifying,
            textInputAction: .next,
          ),
          MoodiaryField(
            controller: _confirmKeyController,
            label: '确认密码',
            errorText: _confirmError,
            obscureText: true,
            enabled: !_verifying,
          ),
          if (widget.onRemove != null)
            MoodiaryDangerRow(
              label: '关闭加密',
              icon: LucideIcons.shieldOff,
              onPressed: _verifying ? null : _remove,
            ),
        ],
      ),
    );
  }
}
