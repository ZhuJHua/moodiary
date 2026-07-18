import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_core/moodiary_core.dart';
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
      leading: const Icon(Icons.key_rounded),
      subtitle: hasKey ? '已开启' : '未开启',
      trailing: IconButton.filled(
        tooltip: '管理加密',
        icon: Icon(Icons.settings_rounded, color: scheme.onPrimary),
        onPressed: () => _showKeyManageSheet(context, ref, hasKey),
      ),
    );
  }

  Future<void> _showKeyManageSheet(
    BuildContext context,
    WidgetRef ref,
    bool hasExistingKey,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _KeyManageSheet(
        hasExistingKey: hasExistingKey,
        onSubmit: (newKey) async {
          Navigator.of(ctx).pop();
          await applyUserKeyChange(
            context: context,
            ref: ref,
            newKey: newKey,
          );
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
  final _formKey = GlobalKey<FormState>();

  bool _currentVerified = false;
  bool _verifying = false;

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
    setState(() => _verifying = true);
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
    });
    if (ok) {
      toast.success(message: '验证成功');
    } else {
      toast.error(message: '密码不正确');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Row(
              children: [
                Icon(Icons.key_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  '加密管理',
                  style: context.textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (widget.hasExistingKey) ...[
              TextFormField(
                controller: _currentKeyController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: '当前密码',
                  hintText: '请输入当前密码进行验证',
                  border: const OutlineInputBorder(),
                  suffixIcon: _currentVerified
                      ? Icon(Icons.check_circle_rounded, color: scheme.primary)
                      : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _currentVerified = false;
                  });
                },
                validator: (value) {
                  if (widget.hasExistingKey && !_currentVerified) {
                    return '请先验证当前密码';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: _verifying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_rounded, size: 18),
                  label: const Text('验证'),
                  onPressed: _verifying ? null : _verifyCurrent,
                ),
              ),
              const SizedBox(height: 16),
            ],

            TextFormField(
              controller: _newKeyController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: widget.hasExistingKey ? '新密码' : '加密密码',
                hintText: widget.hasExistingKey
                    ? '请输入新密码（数据密钥不变，云端无需重新加密）'
                    : '请设置加密密码',
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入密码';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _confirmKeyController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '确认密码',
                hintText: '请再次输入密码',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value != _newKeyController.text) {
                  return '两次输入的密码不一致';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                if (widget.onRemove != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('关闭加密'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.error,
                        side: BorderSide(color: scheme.error),
                      ),
                      // 关闭加密须先验证当前密码，防止拿到已解锁设备者直接解除加密。
                      onPressed: () {
                        if (!_currentVerified) {
                          toast.error(message: '请先验证当前密码');
                          return;
                        }
                        widget.onRemove!();
                      },
                    ),
                  ),
                if (widget.onRemove != null) const SizedBox(width: 12),
                Expanded(
                  flex: widget.onRemove != null ? 2 : 1,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('保存'),
                    onPressed: () {
                      if (!_formKey.currentState!.validate()) return;
                      widget.onSubmit(_newKeyController.text.trim());
                    },
                  ),
                ),
              ],
            ),
            ],
          ),
        ),
      ),
    );
  }
}
