import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

/// 设置页应用锁管理（开关 + 改密 + 生物识别开关）；解锁时机由 `/lock` 负责，此处只管开关与凭据。
class AppLockTile extends StatefulWidget {
  const AppLockTile({super.key});

  @override
  State<AppLockTile> createState() => _AppLockTileState();
}

class _AppLockTileState extends State<AppLockTile> {
  late final Future<bool> _bioSupported = BiometricAuth.canCheckBiometrics();

  Future<void> _onTapLock(bool currentlyOn) async {
    final confirm = await MAlert.confirm(
      context,
      title: l10n.lock.title,
      message: currentlyOn ? l10n.lock.turnOffMessage : l10n.lock.turnOnMessage,
      confirmLabel: currentlyOn
          ? l10n.lock.turnOffAction
          : l10n.lock.turnOnAction,
    );
    if (!confirm || !mounted) return;
    await MSheet.show<void>(
      context,
      builder: (_) =>
          currentlyOn ? const RemovePasswordSheet() : const SetPasswordSheet(),
    );
  }

  Future<void> _changePassword() async {
    await MSheet.show<void>(
      context,
      builder: (_) => const ChangePasswordSheet(),
    );
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // 开启前先验证一次，确认设备已录入且本人可用。
      final ok = await BiometricAuth.check();
      if (!ok) return;
      await MoodiaryKVs.supportBiometrics.set(true);
    } else {
      await MoodiaryKVs.supportBiometrics.set(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return ValueListenableBuilder(
      valueListenable: MoodiaryKVs.lock.getNotifier(),
      builder: (context, lock, _) {
        return Column(
          children: [
            SettingListTile(
              isFirst: true,
              title: context.l10n.lock.title,
              leading: const Icon(LucideIcons.lock),
              trailing: Text(
                lock ? context.l10n.lock.enabled : context.l10n.lock.disabled,
                style: theme.typography.bodySmall.primary,
              ),
              onTap: () => _onTapLock(lock),
            ),
            if (lock)
              SettingListTile(
                title: context.l10n.lock.changePassword,
                leading: const Icon(LucideIcons.keyRound),
                onTap: _changePassword,
              ),
            if (lock)
              ValueListenableBuilder(
                valueListenable: MoodiaryKVs.lockNow.getNotifier(),
                builder: (context, lockNow, _) {
                  return SettingSwitchListTile(
                    title: context.l10n.lock.lockNow,
                    subtitle: context.l10n.lock.lockNowSubtitle,
                    secondary: const Icon(LucideIcons.lockKeyhole),
                    value: lockNow,
                    onChanged: (v) => MoodiaryKVs.lockNow.set(v),
                  );
                },
              ),
            if (lock)
              FutureBuilder<bool>(
                future: _bioSupported,
                builder: (context, snapshot) {
                  if (snapshot.data != true) return const SizedBox.shrink();
                  return ValueListenableBuilder(
                    valueListenable: MoodiaryKVs.supportBiometrics
                        .getNotifier(),
                    builder: (context, bio, _) {
                      return SettingSwitchListTile(
                        title: context.l10n.lock.biometric,
                        subtitle: context.l10n.lock.biometricSubtitle,
                        secondary: const Icon(LucideIcons.fingerprint),
                        value: bio,
                        onChanged: _toggleBiometric,
                      );
                    },
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

/// PIN 键盘自己就是完整版式：输满即完成，没有需要确认的中间态，所以不给动作条。
class _SheetScaffold extends StatelessWidget {
  final Widget child;

  const _SheetScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return MSheetScaffold<void>(
      child: Padding(padding: const .symmetric(vertical: 8), child: child),
    );
  }
}

class SetPasswordSheet extends StatefulWidget {
  const SetPasswordSheet({super.key});

  @override
  State<SetPasswordSheet> createState() => _SetPasswordSheetState();
}

class _SetPasswordSheetState extends State<SetPasswordSheet> {
  final _pad = LockPinPadController();
  String? _first; // 第一遍输入；null 表示尚在第一遍
  String? _error;

  Future<void> _onCompleted(String pin) async {
    if (_first == null) {
      setState(() {
        _first = pin;
        _error = null;
      });
      _pad.clear();
      return;
    }
    if (pin == _first) {
      await MoodiaryKVs.lock.set(true);
      await MoodiaryKVs.password.set(pin);
      if (!mounted) return;
      Navigator.of(context).pop();
      toast.success(message: context.l10n.lock.turnedOn);
    } else {
      setState(() {
        _first = null;
        _error = context.l10n.lock.mismatch;
      });
      _pad.reject();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      child: LockPinPad(
        controller: _pad,
        title: _first == null
            ? context.l10n.lock.setPassword
            : context.l10n.lock.confirmPassword,
        error: _error,
        onCompleted: _onCompleted,
      ),
    );
  }
}

class RemovePasswordSheet extends StatefulWidget {
  const RemovePasswordSheet({super.key});

  @override
  State<RemovePasswordSheet> createState() => _RemovePasswordSheetState();
}

class _RemovePasswordSheetState extends State<RemovePasswordSheet> {
  final _pad = LockPinPadController();
  String? _error;

  bool get _supportBio => MoodiaryKVs.supportBiometrics.get() == true;

  Future<void> _disable() async {
    await MoodiaryKVs.lock.set(false);
    await MoodiaryKVs.password.remove();
    await MoodiaryKVs.supportBiometrics.set(false);
    await MoodiaryKVs.lockNow.set(false);
    if (!mounted) return;
    Navigator.of(context).pop();
    toast.success(message: context.l10n.lock.turnedOff);
  }

  void _onCompleted(String pin) {
    if (pin == (MoodiaryKVs.password.get() ?? '')) {
      _disable();
    } else {
      setState(() => _error = context.l10n.lock.wrongPassword);
      _pad.reject();
    }
  }

  Future<void> _onBiometric() async {
    if (await BiometricAuth.check()) await _disable();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      child: LockPinPad(
        controller: _pad,
        title: context.l10n.lock.enterToTurnOff,
        error: _error,
        showBiometric: _supportBio,
        onBiometric: _onBiometric,
        onCompleted: _onCompleted,
      ),
    );
  }
}

class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

enum _ChangePhase { verify, enterNew, confirmNew }

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _pad = LockPinPadController();
  _ChangePhase _phase = .verify;
  String? _newPin;
  String? _error;

  bool get _supportBio => MoodiaryKVs.supportBiometrics.get() == true;

  String get _title => switch (_phase) {
    .verify => context.l10n.lock.verifyCurrent,
    .enterNew => context.l10n.lock.enterNew,
    .confirmNew => context.l10n.lock.confirmNew,
  };

  void _toEnterNew() {
    setState(() {
      _phase = .enterNew;
      _error = null;
    });
    _pad.clear();
  }

  Future<void> _onCompleted(String pin) async {
    switch (_phase) {
      case .verify:
        if (pin == (MoodiaryKVs.password.get() ?? '')) {
          _toEnterNew();
        } else {
          setState(() => _error = context.l10n.lock.wrongPassword);
          _pad.reject();
        }
      case .enterNew:
        setState(() {
          _newPin = pin;
          _phase = .confirmNew;
          _error = null;
        });
        _pad.clear();
      case .confirmNew:
        if (pin == _newPin) {
          await MoodiaryKVs.password.set(pin);
          if (!mounted) return;
          Navigator.of(context).pop();
          toast.success(message: context.l10n.lock.passwordChanged);
        } else {
          setState(() {
            _newPin = null;
            _phase = .enterNew;
            _error = context.l10n.lock.mismatch;
          });
          _pad.reject();
        }
    }
  }

  Future<void> _onBiometric() async {
    if (_phase == .verify && await BiometricAuth.check()) {
      _toEnterNew();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      child: LockPinPad(
        controller: _pad,
        title: _title,
        error: _error,
        showBiometric: _phase == .verify && _supportBio,
        onBiometric: _onBiometric,
        onCompleted: _onCompleted,
      ),
    );
  }
}
