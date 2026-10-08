import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

class AppLockTile extends StatefulWidget {
  const AppLockTile({super.key});

  @override
  State<AppLockTile> createState() => _AppLockTileState();
}

class _AppLockTileState extends State<AppLockTile> {
  late final Future<IconData?> _bioIcon = () async {
    final (supported, icon) = await (
      BiometricAuth.canCheckBiometrics(),
      AppAuth.biometricIcon,
    ).wait;
    return supported ? icon : null;
  }();

  Future<void> _toggleLock(bool value) async {
    if (value) {
      await MSheet.show<void>(
        context,
        builder: (_) => const _SetPasswordSheet(),
      );
    } else {
      await AppAuth.guard(context, .passcodeDisable, _disable);
    }
  }

  Future<void> _disable() async {
    await AppLockPin.clear();
    MoodiaryKVs.supportBiometrics.set(false);
    MoodiaryKVs.lockNow.set(false);
    toast.success(message: l10n.lock.turnedOff);
  }

  Future<void> _changePassword() async {
    await AppAuth.guard(
      context,
      .passcodeChange,
      () => MSheet.show<void>(
        context,
        builder: (_) => const _SetPasswordSheet(change: true),
      ),
    );
  }

  Future<void> _toggleBiometric(bool value) async {
    if (!value) {
      MoodiaryKVs.supportBiometrics.set(false);
      return;
    }
    await AppAuth.guard(context, .biometricEnable, () async {
      if (await AppAuth.biometric()) MoodiaryKVs.supportBiometrics.set(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppLockPin.enabled,
      builder: (context, lock, _) {
        return FutureBuilder<IconData?>(
          future: _bioIcon,
          builder: (context, snapshot) {
            final rows = <Widget>[
              SettingSwitchListTile(
                title: context.l10n.lock.title,
                subtitle: context.l10n.lock.subtitle,
                secondary: const Icon(LucideIcons.lock),
                value: lock,
                onChanged: _toggleLock,
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
                if (snapshot.data case final icon?)
                  ValueListenableBuilder(
                    valueListenable: MoodiaryKVs.supportBiometrics
                        .getNotifier(),
                    builder: (context, bio, _) {
                      return SettingSwitchListTile(
                        title: context.l10n.lock.biometric,
                        subtitle: context.l10n.lock.biometricSubtitle,
                        secondary: Icon(icon),
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

class _SetPasswordSheet extends StatefulWidget {
  final bool change;

  const _SetPasswordSheet({this.change = false});

  @override
  State<_SetPasswordSheet> createState() => _SetPasswordSheetState();
}

class _SetPasswordSheetState extends State<_SetPasswordSheet> {
  final _pad = LockPinPadController();
  String? _first;
  String? _error;

  Future<bool> _save(String pin) async {
    try {
      await AppLockPin.set(pin);
      return true;
    } catch (e, s) {
      logger.e('访问密码：写入 PIN 失败', error: e, stackTrace: s);
      return false;
    }
  }

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
      if (!await _save(pin)) {
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
      toast.success(
        message: widget.change
            ? context.l10n.lock.passwordChanged
            : context.l10n.lock.turnedOn,
      );
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
    return MSheetScaffold<void>(
      child: Padding(
        padding: const .symmetric(vertical: 8),
        child: LockPinPad(
          controller: _pad,
          title: switch ((_first == null, widget.change)) {
            (true, false) => context.l10n.lock.setPassword,
            (true, true) => context.l10n.lock.enterNew,
            (false, false) => context.l10n.lock.confirmPassword,
            (false, true) => context.l10n.lock.confirmNew,
          },
          error: _error,
          onCompleted: _onCompleted,
        ),
      ),
    );
  }
}
