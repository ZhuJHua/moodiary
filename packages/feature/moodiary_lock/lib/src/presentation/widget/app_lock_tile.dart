import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:mui/mui.dart';

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
      builder: (_) => currentlyOn
          ? const _RemovePasswordSheet()
          : const _SetPasswordSheet(),
    );
  }

  Future<void> _changePassword() async {
    await MSheet.show<void>(
      context,
      builder: (_) => const _ChangePasswordSheet(),
    );
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final ok = await BiometricAuth.check(reason: l10n.lock.biometricReason);
      if (!ok) return;
      MoodiaryKVs.supportBiometrics.set(true);
    } else {
      MoodiaryKVs.supportBiometrics.set(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return ValueListenableBuilder(
      valueListenable: AppLockPin.enabled,
      builder: (context, lock, _) {
        return FutureBuilder<bool>(
          future: _bioSupported,
          builder: (context, snapshot) {
            final rows = <Widget>[
              SettingListTile(
                title: context.l10n.lock.title,
                leading: const Icon(LucideIcons.lock),
                trailing: Text(
                  lock ? context.l10n.lock.enabled : context.l10n.lock.disabled,
                  style: theme.typography.bodySmall.primary,
                ),
                onTap: () => _onTapLock(lock),
              ),
              if (lock) ...[
                SettingListTile(
                  title: context.l10n.lock.changePassword,
                  leading: const Icon(LucideIcons.keyRound),
                  onTap: _changePassword,
                ),
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
                if (snapshot.data == true)
                  ValueListenableBuilder(
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
                  ),
              ],
            ];
            return Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const MSettingDivider(),
                  rows[i],
                ],
              ],
            );
          },
        );
      },
    );
  }
}

Future<bool> _savePin(String pin) async {
  try {
    await AppLockPin.set(pin);
    return true;
  } catch (e, s) {
    logger.e('应用锁：写入 PIN 失败', error: e, stackTrace: s);
    return false;
  }
}

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

class _SetPasswordSheet extends StatefulWidget {
  const _SetPasswordSheet();

  @override
  State<_SetPasswordSheet> createState() => _SetPasswordSheetState();
}

class _SetPasswordSheetState extends State<_SetPasswordSheet> {
  final _pad = LockPinPadController();
  String? _first;
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
      if (!await _savePin(pin)) {
        if (!mounted) return;
        setState(() {
          _first = null;
          _error = context.l10n.lock.saveFailed;
        });
        _pad.reject();
        return;
      }
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

class _RemovePasswordSheet extends StatefulWidget {
  const _RemovePasswordSheet();

  @override
  State<_RemovePasswordSheet> createState() => _RemovePasswordSheetState();
}

class _RemovePasswordSheetState extends State<_RemovePasswordSheet> {
  final _pad = LockPinPadController();
  String? _error;

  bool get _supportBio => MoodiaryKVs.supportBiometrics.get() == true;

  Future<void> _disable() async {
    await AppLockPin.clear();
    MoodiaryKVs.supportBiometrics.set(false);
    MoodiaryKVs.lockNow.set(false);
    if (!mounted) return;
    Navigator.of(context).pop();
    toast.success(message: context.l10n.lock.turnedOff);
  }

  Future<void> _onCompleted(String pin) async {
    final matched = await AppLockPin.verify(pin);
    if (!mounted) return;
    if (matched) {
      await _disable();
    } else {
      setState(() => _error = context.l10n.lock.wrongPassword);
      _pad.reject();
    }
  }

  Future<void> _onBiometric() async {
    if (await BiometricAuth.check(reason: l10n.lock.biometricReason)) {
      await _disable();
    }
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

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

enum _ChangePhase { verify, enterNew, confirmNew }

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
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
        final matched = await AppLockPin.verify(pin);
        if (!mounted) return;
        if (matched) {
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
          if (!await _savePin(pin)) {
            if (!mounted) return;
            setState(() {
              _newPin = null;
              _phase = .enterNew;
              _error = context.l10n.lock.saveFailed;
            });
            _pad.reject();
            return;
          }
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
    if (_phase == .verify &&
        await BiometricAuth.check(reason: l10n.lock.biometricReason)) {
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
