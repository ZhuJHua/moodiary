import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_sync/src/application/user_key_controller.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_key_manager.dart';
import 'package:moodiary_sync/src/data/sync_provider_scope.dart';
import 'package:moodiary_sync/src/presentation/widget/sync_key_guard.dart';
import 'package:moodiary_sync/src/presentation/widget/user_key_change_flow.dart';

enum UserKeySheetMode { off, on, locked, keyfileMissing }

Future<UserKeySheetMode> resolveUserKeySheetMode() async {
  final hasKey = await SyncKeyManager.loadDek() != null;
  final backend = currentSyncBackend();
  if (backend != null && await backend.isReady()) {
    switch (await SyncKeyManager.probeRemote(backend)) {
      case .locked:
        return .locked;
      case .keyfileMissing:
        return .keyfileMissing;
      case .plaintext || .unlocked || .unknown:
        break;
    }
  }
  return hasKey ? .on : .off;
}

Future<void> showUserKeySheet(
  BuildContext context,
  WidgetRef ref,
  UserKeySheetMode mode,
) async {
  await MSheet.show<String>(
    context,
    builder: (ctx) => _KeyManageSheet(
      mode: mode,
      onSubmit: (newKey) async {
        Navigator.of(ctx).pop();
        Future<bool> apply() =>
            applyUserKeyChange(context: context, ref: ref, newKey: newKey);
        if (mode == .on) {
          await AppAuth.guard(context, .syncKeyChange, apply);
        } else {
          await apply();
        }
      },
      onRemove: () async {
        Navigator.of(ctx).pop();
        await applyUserKeyChange(context: context, ref: ref, newKey: null);
      },
      onUnlock: () async {
        Navigator.of(ctx).pop();
        final backend = currentSyncBackend();
        if (backend == null) return;
        await ensureSyncKeyReady(context: context, ref: ref, backend: backend);
      },
      onReset: () async {
        Navigator.of(ctx).pop();
        final backend = currentSyncBackend();
        if (backend == null) return;
        await resetAndOfferNewKey(context: context, ref: ref, backend: backend);
      },
    ),
  );
}

Future<void> resetAndOfferNewKey({
  required BuildContext context,
  required WidgetRef ref,
  required IRemoteSyncBackend backend,
}) async {
  if (!await confirmRemoteReset(context) || !context.mounted) return;
  final choice = await MSheet.show<String>(
    context,
    builder: (ctx) => _KeyManageSheet(
      mode: .off,
      forReset: true,
      onSubmit: (newKey) => Navigator.of(ctx).pop(newKey),
    ),
  );
  if (choice == null || !context.mounted) return;
  await resetRemote(
    context: context,
    ref: ref,
    backend: backend,
    passphrase: choice.isEmpty ? null : choice,
  );
}

class UserKeyTile extends ConsumerStatefulWidget {
  const UserKeyTile({super.key});

  @override
  ConsumerState<UserKeyTile> createState() => _UserKeyTileState();
}

class _UserKeyTileState extends ConsumerState<UserKeyTile> {
  bool _probing = false;

  Future<void> _open() async {
    setState(() => _probing = true);
    final mode = await resolveUserKeySheetMode();
    if (!mounted) return;
    setState(() => _probing = false);
    await showUserKeySheet(context, ref, mode);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(syncDekControllerProvider);
    final dekB64 = async.maybeWhen(data: (v) => v, orElse: () => null);
    final hasKey = dekB64 != null && dekB64.isNotEmpty;
    final scheme = context.theme.colors;

    return SettingListTile(
      title: context.l10n.sync.e2eTitle,
      leading: const Icon(LucideIcons.key),
      subtitle: hasKey ? context.l10n.sync.e2eOn : context.l10n.sync.e2eOff,
      trailing: IconButton.filled(
        tooltip: context.l10n.sync.e2eManage,
        icon: _probing
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.onPrimary,
                ),
              )
            : Icon(LucideIcons.settings, color: scheme.onPrimary),
        onPressed: _probing ? null : _open,
      ),
    );
  }
}

class _KeyManageSheet extends StatefulWidget {
  final UserKeySheetMode mode;
  final bool forReset;
  final void Function(String newKey) onSubmit;
  final VoidCallback? onRemove;
  final VoidCallback? onUnlock;
  final VoidCallback? onReset;

  const _KeyManageSheet({
    required this.mode,
    this.forReset = false,
    required this.onSubmit,
    this.onRemove,
    this.onUnlock,
    this.onReset,
  });

  @override
  State<_KeyManageSheet> createState() => _KeyManageSheetState();
}

class _KeyManageSheetState extends State<_KeyManageSheet> {
  final _newKeyController = TextEditingController();
  final _confirmKeyController = TextEditingController();

  String? _newError;
  String? _confirmError;

  bool get _locked => widget.mode == .locked || widget.mode == .keyfileMissing;

  @override
  void dispose() {
    _newKeyController.dispose();
    _confirmKeyController.dispose();
    super.dispose();
  }

  void _submit() {
    final newError = _newKeyController.text.trim().isEmpty
        ? l10n.sync.keyNeedPassword
        : null;
    final confirmError = _confirmKeyController.text != _newKeyController.text
        ? l10n.sync.keyMismatch
        : null;
    setState(() {
      _newError = newError;
      _confirmError = confirmError;
    });
    if (newError == null && confirmError == null) {
      widget.onSubmit(_newKeyController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n.sync;
    final scheme = context.theme.colors;
    final on = widget.mode == .on;

    return MSheetScaffold<String>(
      title: l10n.e2eTitle,
      subtitle: switch (widget.mode) {
        .on => l10n.e2eOn,
        .off => l10n.e2eOff,
        .locked || .keyfileMissing => l10n.e2eLocked,
      },
      icon: _locked ? LucideIcons.lockKeyhole : LucideIcons.key,
      isDestructive: _locked,
      actions: _locked
          ? [MAction(label: context.l10n.common.close)]
          : [
              widget.forReset
                  ? MAction(label: l10n.keySkipEncryption, value: '')
                  : MAction(label: context.l10n.common.cancel),
              MAction(
                label: on ? l10n.keyChangeAction : l10n.keyEnableAction,
                isPrimary: true,
                onPressed: _submit,
              ),
            ],
      child: _locked
          ? _buildLocked(context)
          : Column(
              mainAxisSize: .min,
              crossAxisAlignment: .stretch,
              spacing: 14,
              children: [
                MField(
                  controller: _newKeyController,
                  label: on ? l10n.keyNew : l10n.keyPassword,
                  errorText: _newError,
                  obscureText: true,
                  textInputAction: .next,
                ),
                MField(
                  controller: _confirmKeyController,
                  label: l10n.keyConfirm,
                  errorText: _confirmError,
                  obscureText: true,
                  onSubmitted: (_) => _submit(),
                ),
                if (on) ...[
                  Divider(
                    height: 12,
                    color: scheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                  MDangerRow(
                    label: l10n.keyTurnOff,
                    icon: LucideIcons.shieldOff,
                    onPressed: widget.onRemove,
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildLocked(BuildContext context) {
    final l10n = context.l10n.sync;
    final scheme = context.theme.colors;
    final missing = widget.mode == .keyfileMissing;
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: 12,
      children: [
        Container(
          padding: const .symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: MuiRadius.lg,
          ),
          child: Row(
            crossAxisAlignment: .start,
            spacing: 12,
            children: [
              Icon(
                LucideIcons.cloudAlert,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              Expanded(
                child: Text(
                  missing ? l10n.keyGuardMissing : l10n.keyLockedNotice,
                  style: context.theme.typography.bodyMedium.onSurface,
                ),
              ),
            ],
          ),
        ),
        if (!missing)
          FilledButton.icon(
            onPressed: widget.onUnlock,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(LucideIcons.lockKeyholeOpen, size: 18),
            label: Text(l10n.keyUnlockAction),
          ),
        Divider(
          height: 12,
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
        MDangerRow(
          label: l10n.keyForgotReset,
          icon: LucideIcons.rotateCcw,
          onPressed: widget.onReset,
        ),
      ],
    );
  }
}
