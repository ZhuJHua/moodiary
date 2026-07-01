import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary/feature/sync/application/user_key_controller.dart';
import 'package:moodiary/feature/sync/presentation/widget/user_key_change_flow.dart';

/// 用户密钥设置项。**加密语义**：配置密钥即开启加密，清空密钥即关闭加密。
class UserKeyTile extends ConsumerWidget {
  final bool isFirst;
  final bool isLast;

  const UserKeyTile({super.key, this.isFirst = false, this.isLast = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userKeyControllerProvider);
    final current = async.maybeWhen(data: (v) => v ?? '', orElse: () => '');
    final hasValue = current.trim().isNotEmpty;
    final scheme = context.colorScheme;

    return SettingListTile(
      isFirst: isFirst,
      isLast: isLast,
      title: '用户密钥',
      leading: const Icon(Icons.key_rounded),
      subtitle: hasValue ? '已配置' : '未配置',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Builder(
            builder: (btnContext) => IconButton.filledTonal(
              tooltip: '生成二维码',
              icon: const Icon(Icons.qr_code_rounded),
              onPressed: () {
                if (!hasValue) {
                  toast.info(message: '用户密钥暂未配置，无法生成');
                  return;
                }
                showPopupWidget(
                  targetContext: btnContext,
                  child: EncryptQrCode(
                    data: current,
                    prefix: 'userKey:',
                    size: 160,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filled(
            tooltip: '管理密钥',
            icon: Icon(Icons.settings_rounded, color: scheme.onPrimary),
            onPressed: () => _showKeyManageSheet(context, ref, current),
          ),
        ],
      ),
    );
  }

  Future<void> _showKeyManageSheet(
    BuildContext context,
    WidgetRef ref,
    String currentKey,
  ) async {
    final hasExistingKey = currentKey.trim().isNotEmpty;
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
                  '密钥管理',
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
                  labelText: '当前密钥',
                  hintText: '请输入当前密钥进行验证',
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
                    return '请先验证当前密钥';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.verified_rounded, size: 18),
                  label: const Text('验证'),
                  onPressed: () async {
                    final currentKey = await MoodiarySecureKVs.userKey.get();
                    if (_currentKeyController.text.trim() == currentKey) {
                      setState(() => _currentVerified = true);
                      toast.success(message: '验证成功');
                    } else {
                      toast.error(message: '密钥不正确');
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            TextFormField(
              controller: _newKeyController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '新密钥',
                hintText: '请输入新密钥',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入新密钥';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _confirmKeyController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '确认新密钥',
                hintText: '请再次输入新密钥',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value != _newKeyController.text) {
                  return '两次输入的密钥不一致';
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
                      label: const Text('移除密钥'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.error,
                        side: BorderSide(color: scheme.error),
                      ),
                      // 移除（= 关闭加密）须先验证当前密钥，防止拿到已解锁设备者直接解除加密。
                      onPressed: () {
                        if (!_currentVerified) {
                          toast.error(message: '请先验证当前密钥');
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
                    label: const Text('保存密钥'),
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
