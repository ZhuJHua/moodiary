import 'dart:async';
import 'dart:io';

import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:mui/mui.dart';

enum SensitiveAction {
  syncKeyChange(LucideIcons.keyRound),
  syncKeyDisable(LucideIcons.shieldOff, destructive: true),
  syncCloudReset(LucideIcons.rotateCcw, destructive: true),
  passcodeDisable(LucideIcons.lockOpen, destructive: true),
  passcodeChange(LucideIcons.keyRound),
  dataExport(LucideIcons.download),
  biometricEnable(LucideIcons.fingerprintPattern),
  lanSend(LucideIcons.radioTower),
  syncConfig(LucideIcons.cloudCog);

  final IconData icon;
  final bool destructive;

  const SensitiveAction(this.icon, {this.destructive = false});

  String get title => switch (this) {
    syncKeyChange => l10n.lock.actionSyncKeyChange,
    syncKeyDisable => l10n.lock.actionSyncKeyDisable,
    syncCloudReset => l10n.lock.actionSyncCloudReset,
    passcodeDisable => l10n.lock.actionPasscodeDisable,
    passcodeChange => l10n.lock.actionPasscodeChange,
    dataExport => l10n.lock.actionDataExport,
    biometricEnable => l10n.lock.actionBiometricEnable,
    lanSend => l10n.lock.actionLanSend,
    syncConfig => l10n.lock.actionSyncConfig,
  };
}

abstract final class AppAuth {
  static final Object _verified = Object();

  static bool get _insideGuard => Zone.current[_verified] == true;

  static Future<bool> verify(
    BuildContext context,
    SensitiveAction action,
  ) async {
    if (_insideGuard || !AppLockPin.enabled.value) return true;
    final ok = await MSheet.show<bool>(
      context,
      builder: (ctx) => MSheetScaffold<bool>(
        title: action.title,
        subtitle: ctx.l10n.lock.authSubtitle,
        icon: action.icon,
        isDestructive: action.destructive,
        child: Padding(
          padding: const .only(top: 8, bottom: 8),
          child: PasscodeGate(
            title: ctx.l10n.lock.prompt,
            onVerified: () => _close(ctx),
          ),
        ),
      ),
    );
    return ok ?? false;
  }

  static void _close(BuildContext ctx) {
    final route = ModalRoute.of<bool>(ctx);
    if (route == null || !route.isActive) return;
    final navigator = Navigator.of(ctx);
    if (route.isCurrent) {
      navigator.pop(true);
    } else {
      navigator.removeRoute(route, true);
    }
  }

  static Future<bool> biometric({String? fallback}) => BiometricAuth.check(
    title: l10n.lock.biometricTitle,
    reason: l10n.lock.biometricReason,
    cancel: l10n.common.cancel,
    fallback: fallback,
  );

  static Future<IconData> get biometricIcon async =>
      await BiometricAuth.usesFace
      ? LucideIcons.scanFace
      : LucideIcons.fingerprintPattern;

  static Future<T?> guard<T>(
    BuildContext context,
    SensitiveAction action,
    Future<T> Function() body,
  ) async {
    if (!await verify(context, action)) return null;
    return runZoned(body, zoneValues: {_verified: true});
  }
}

class PasscodeGate extends StatefulWidget {
  final String title;
  final VoidCallback onVerified;

  const PasscodeGate({
    super.key,
    required this.title,
    required this.onVerified,
  });

  @override
  State<PasscodeGate> createState() => _PasscodeGateState();
}

class _PasscodeGateState extends State<PasscodeGate> {
  final _pad = LockPinPadController();
  String? _error;
  bool _verifying = false;
  bool _done = false;
  Timer? _cooldown;
  bool _lockedOut = false;
  IconData _bioIcon = LucideIcons.fingerprintPattern;

  bool get _biometric =>
      (Platform.isAndroid || Platform.isIOS) &&
      MoodiaryKVs.supportBiometrics.get() == true;

  @override
  void initState() {
    super.initState();
    if (_biometric) {
      AppAuth.biometricIcon.then((icon) {
        if (mounted) setState(() => _bioIcon = icon);
      });
    }
    final left = AppLockPin.lockoutLeft();
    if (left > .zero) {
      _startCooldown(left);
    } else if (_biometric) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  @override
  void dispose() {
    _cooldown?.cancel();
    super.dispose();
  }

  void _pass() {
    setState(() => _done = true);
    widget.onVerified();
  }

  Future<void> _tryBiometric() async {
    if (_lockedOut || _verifying || _done || !mounted) return;
    final ok = await AppAuth.biometric(
      fallback: l10n.lock.biometricUsePasscode,
    );
    if (!ok || !mounted) return;
    AppLockPin.resetAttempts();
    _pass();
  }

  String _cooldownText(Duration left) => l10n.lock.cooldown(
    seconds: (left.inMicroseconds / Duration.microsecondsPerSecond).ceil(),
  );

  void _startCooldown(Duration left) {
    _lockedOut = true;
    _error = _cooldownText(left);
    _cooldown?.cancel();
    _cooldown = .periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      final left = AppLockPin.lockoutLeft();
      setState(() {
        _lockedOut = left > .zero;
        _error = _lockedOut ? _cooldownText(left) : null;
      });
      if (left == .zero) timer.cancel();
    });
  }

  Future<void> _onCompleted(String pin) async {
    if (_verifying || _lockedOut || _done) return;
    setState(() => _verifying = true);
    final result = await AppLockPin.attempt(pin);
    if (!mounted) return;
    setState(() => _verifying = false);
    switch (result) {
      case PinAccepted():
        _pass();
      case PinRejected(:final remaining):
        setState(() => _error = l10n.lock.attemptsLeft(count: remaining));
        _pad.reject();
      case PinLockedOut(:final left):
        _pad.reject();
        setState(() => _startCooldown(left));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LockPinPad(
      controller: _pad,
      title: widget.title,
      error: _error,
      enabled: !_verifying && !_lockedOut && !_done,
      showBiometric: _biometric && !_lockedOut,
      onBiometric: _tryBiometric,
      biometricIcon: _bioIcon,
      onCompleted: _onCompleted,
    );
  }
}
