import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_sync/src/application/user_key_controller.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_key_manager.dart';
import 'package:moodiary_sync/src/presentation/widget/user_key_change_flow.dart';
import 'package:mui/mui.dart';

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
    final scheme = context.theme.colors;

    return SettingListTile(
      isFirst: isFirst,
      isLast: isLast,
      title: context.l10n.sync.e2eTitle,
      leading: const Icon(LucideIcons.key),
      subtitle: hasKey ? context.l10n.sync.e2eOn : context.l10n.sync.e2eOff,
      trailing: IconButton.filled(
        tooltip: context.l10n.sync.e2eManage,
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
    await MSheet.show<void>(
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
      backend = .get();
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
      _currentError = ok ? null : l10n.sync.keyWrong;
    });
    if (ok) toast.success(message: l10n.sync.keyVerified);
  }

  bool _validate() {
    final currentError = widget.hasExistingKey && !_currentVerified
        ? l10n.sync.keyVerifyFirst
        : null;
    final newError = _newKeyController.text.trim().isEmpty
        ? l10n.sync.keyNeedPassword
        : null;
    final confirmError = _confirmKeyController.text != _newKeyController.text
        ? l10n.sync.keyMismatch
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
      setState(() => _currentError = l10n.sync.keyVerifyFirst);
      return;
    }
    widget.onRemove!();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return MSheetScaffold<void>(
      title: context.l10n.sync.keyManageTitle,
      subtitle: widget.hasExistingKey
          ? context.l10n.sync.e2eOn
          : context.l10n.sync.e2eOff,
      icon: LucideIcons.key,
      actions: [
        MAction(label: context.l10n.common.cancel, enabled: !_verifying),
        MAction(
          label: context.l10n.common.save,
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
            MField(
              controller: _currentKeyController,
              label: context.l10n.sync.keyCurrent,
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
                      tooltip: context.l10n.sync.keyVerify,
                      icon: _verifying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(LucideIcons.badgeCheck, size: 18),
                      visualDensity: .compact,
                      onPressed: _verifying ? null : _verifyCurrent,
                    ),
            ),
          MField(
            controller: _newKeyController,
            label: widget.hasExistingKey
                ? context.l10n.sync.keyNew
                : context.l10n.sync.keyPassword,
            errorText: _newError,
            obscureText: true,
            enabled: !_verifying,
            textInputAction: .next,
          ),
          MField(
            controller: _confirmKeyController,
            label: context.l10n.sync.keyConfirm,
            errorText: _confirmError,
            obscureText: true,
            enabled: !_verifying,
          ),
          if (widget.onRemove != null)
            MDangerRow(
              label: context.l10n.sync.keyTurnOff,
              icon: LucideIcons.shieldOff,
              onPressed: _verifying ? null : _remove,
            ),
        ],
      ),
    );
  }
}
