import 'package:flutter/material.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:moodiary_core/moodiary_core.dart';

/// 设置页应用锁管理（开关 + 改密 + 生物识别开关）；解锁时机由 `/lock` 负责，此处只管开关与凭据。
class AppLockTile extends StatefulWidget {
  const AppLockTile({super.key});

  @override
  State<AppLockTile> createState() => _AppLockTileState();
}

class _AppLockTileState extends State<AppLockTile> {
  late final Future<bool> _bioSupported = BiometricAuth.canCheckBiometrics();

  Future<void> _onTapLock(bool currentlyOn) async {
    final confirm = await showMoodiaryConfirm(
      context,
      title: '应用锁',
      message: currentlyOn ? '关闭后启动将不再需要密码。' : '开启后，每次启动应用都需要输入密码。',
      confirmLabel: currentlyOn ? '去关闭' : '去设置',
    );
    if (!confirm || !mounted) return;
    await showFloatingModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          currentlyOn ? const RemovePasswordSheet() : const SetPasswordSheet(),
    );
  }

  Future<void> _changePassword() async {
    await showFloatingModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
    final scheme = context.colorScheme;
    return ValueListenableBuilder(
      valueListenable: MoodiaryKVs.lock.getNotifier(),
      builder: (context, lock, _) {
        return Column(
          children: [
            SettingListTile(
              isFirst: true,
              title: '应用锁',
              leading: const Icon(LucideIcons.lock),
              trailing: Text(
                lock ? '已开启' : '未开启',
                style: context.textTheme.bodySmall?.copyWith(
                  color: scheme.primary,
                ),
              ),
              onTap: () => _onTapLock(lock),
            ),
            if (lock)
              SettingListTile(
                title: '修改密码',
                leading: const Icon(LucideIcons.keyRound),
                onTap: _changePassword,
              ),
            if (lock)
              ValueListenableBuilder(
                valueListenable: MoodiaryKVs.lockNow.getNotifier(),
                builder: (context, lockNow, _) {
                  return SettingSwitchListTile(
                    title: '立即锁定',
                    subtitle: '退到后台后再回来需重新解锁',
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
                    valueListenable: MoodiaryKVs.supportBiometrics.getNotifier(),
                    builder: (context, bio, _) {
                      return SettingSwitchListTile(
                        title: '生物识别解锁',
                        subtitle: '用指纹 / 面容快速解锁',
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

class _SheetScaffold extends StatelessWidget {
  final Widget child;

  const _SheetScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: SingleChildScrollView(child: child),
      ),
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
      toast.success(message: '已开启应用锁');
    } else {
      setState(() {
        _first = null;
        _error = '两次输入不一致，请重新设置';
      });
      _pad.reject();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      child: LockPinPad(
        controller: _pad,
        title: _first == null ? '设置密码' : '确认密码',
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
    toast.success(message: '已关闭应用锁');
  }

  void _onCompleted(String pin) {
    if (pin == (MoodiaryKVs.password.get() ?? '')) {
      _disable();
    } else {
      setState(() => _error = '密码错误');
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
        title: '输入密码以关闭',
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
  _ChangePhase _phase = _ChangePhase.verify;
  String? _newPin;
  String? _error;

  bool get _supportBio => MoodiaryKVs.supportBiometrics.get() == true;

  String get _title => switch (_phase) {
    _ChangePhase.verify => '输入当前密码',
    _ChangePhase.enterNew => '设置新密码',
    _ChangePhase.confirmNew => '确认新密码',
  };

  void _toEnterNew() {
    setState(() {
      _phase = _ChangePhase.enterNew;
      _error = null;
    });
    _pad.clear();
  }

  Future<void> _onCompleted(String pin) async {
    switch (_phase) {
      case _ChangePhase.verify:
        if (pin == (MoodiaryKVs.password.get() ?? '')) {
          _toEnterNew();
        } else {
          setState(() => _error = '密码错误');
          _pad.reject();
        }
      case _ChangePhase.enterNew:
        setState(() {
          _newPin = pin;
          _phase = _ChangePhase.confirmNew;
          _error = null;
        });
        _pad.clear();
      case _ChangePhase.confirmNew:
        if (pin == _newPin) {
          await MoodiaryKVs.password.set(pin);
          if (!mounted) return;
          Navigator.of(context).pop();
          toast.success(message: '密码已修改');
        } else {
          setState(() {
            _newPin = null;
            _phase = _ChangePhase.enterNew;
            _error = '两次输入不一致，请重新设置';
          });
          _pad.reject();
        }
    }
  }

  Future<void> _onBiometric() async {
    if (_phase == _ChangePhase.verify && await BiometricAuth.check()) {
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
        showBiometric: _phase == _ChangePhase.verify && _supportBio,
        onBiometric: _onBiometric,
        onCompleted: _onCompleted,
      ),
    );
  }
}
