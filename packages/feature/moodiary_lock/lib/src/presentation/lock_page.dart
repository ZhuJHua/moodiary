import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

const int _pinLength = 4;
const int _maxAttempts = 5;
const int _cooldownSeconds = 30;

class LockPage extends ConsumerStatefulWidget {
  final String? lockType;

  const LockPage({super.key, this.lockType});

  @override
  ConsumerState<LockPage> createState() => _LockPageState();
}

class _LockPageState extends ConsumerState<LockPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final Animation<double> _shake = CurvedAnimation(
    parent: _shakeCtrl,
    curve: Curves.easeInOut,
  );

  String _pin = '';
  bool _unlocked = false;
  String? _error;
  int _failCount = 0;
  int _cooldownLeft = 0;
  Timer? _cooldownTimer;

  bool get _isLocked => _cooldownLeft > 0;
  bool get _supportBio => MoodiaryKVs.supportBiometrics.get() == true;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid || Platform.isIOS) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    if (_isLocked || _unlocked) return;
    if (!_supportBio) return;
    final ok = await BiometricAuth.check(reason: l10n.lock.biometricReason);
    if (!mounted || !ok) return;
    _unlock();
  }

  void _unlock() {
    setState(() => _unlocked = true);
    Future.delayed(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      if (widget.lockType == 'pause') {
        // 命令式 pop 不受 PopScope(canPop:false) 拦截，正常返回被遮挡的页面。
        Navigator.of(context).pop();
      } else {
        const DiaryHomeRoute().go(context);
      }
    });
  }

  void _startCooldown() {
    _cooldownLeft = _cooldownSeconds;
    _error = context.l10n.lock.cooldown(seconds: _cooldownLeft);
    setState(() {});
    _cooldownTimer?.cancel();
    _cooldownTimer = .periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownLeft -= 1;
        if (_cooldownLeft <= 0) {
          timer.cancel();
          _failCount = 0;
          _error = null;
        } else {
          _error = context.l10n.lock.cooldown(seconds: _cooldownLeft);
        }
      });
    });
  }

  void _onDigit(String d) {
    if (_isLocked || _unlocked) return;
    if (_pin.length >= _pinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin = _pin + d;
      _error = null;
    });
    if (_pin.length == _pinLength) {
      // 让最后一个圆点动画完成再校验。
      Future.delayed(const Duration(milliseconds: 120), _verify);
    }
  }

  void _onBackspace() {
    if (_isLocked || _unlocked || _pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _verify() async {
    final stored = MoodiaryKVs.password.get() ?? '';
    if (_pin == stored) {
      _failCount = 0;
      _unlock();
      return;
    }
    _failCount += 1;
    HapticFeedback.mediumImpact();
    _shakeCtrl.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      _shakeCtrl.reverse();
    });
    if (_failCount >= _maxAttempts) {
      _pin = '';
      _startCooldown();
      return;
    }
    final remaining = _maxAttempts - _failCount;
    await Future.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    setState(() {
      _pin = '';
      _error = context.l10n.lock.attemptsLeft(count: remaining);
    });
  }

  /// 在 0~1 区间制造 -10 → +10 → -10 → 0 的水平抖动位移。
  double _shakeOffset(double v) {
    const amp = 10.0;
    if (v <= 0.25) return 4 * amp * v;
    if (v <= 0.75) return amp - 4 * amp * (v - 0.25);
    return -amp + 4 * amp * (v - 0.75);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final scheme = theme.colors;
    final displayLarge = theme.typography.displayLarge.onSurface;
    final dotSize =
        (displayLarge.fontSize ?? 57) * (displayLarge.height ?? 1.12);
    return PopScope(
      // 返回手势不得绕过进入内容；解锁由 _unlock 命令式完成。
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // 启动锁：返回键退出应用；暂停锁：返回既不解锁也不退出，必须验证。
        if (widget.lockType != 'pause') {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(automaticallyImplyLeading: false),
        extendBodyBehindAppBar: true,
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: .min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _unlocked
                      ? Icon(
                          LucideIcons.lockOpen,
                          key: const ValueKey('unlock'),
                          size: 28,
                          color: scheme.primary,
                        )
                      : Icon(
                          LucideIcons.lock,
                          key: const ValueKey('lock'),
                          size: 28,
                          color: scheme.onSurface,
                        ),
                ),
                const SizedBox(height: 24),
                Text(
                  context.l10n.lock.prompt,
                  style: theme.typography.titleMedium.onSurface,
                ),
                const SizedBox(height: 24),
                AnimatedBuilder(
                  animation: _shake,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_shakeOffset(_shake.value), 0),
                      child: child,
                    );
                  },
                  child: Row(
                    mainAxisAlignment: .center,
                    children: .generate(_pinLength, (i) {
                      final filled = i < _pin.length;
                      return Padding(
                        padding: const .symmetric(horizontal: 8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: .circle,
                            color: filled
                                ? scheme.onSurface
                                : scheme.surfaceContainerHighest,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: dotSize * 3 + 20,
                  height: dotSize * 4 + 30,
                  child: GridView.count(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: .zero,
                    children: [
                      for (final d in const [
                        '1',
                        '2',
                        '3',
                        '4',
                        '5',
                        '6',
                        '7',
                        '8',
                        '9',
                      ])
                        _NumButton(
                          label: d,
                          onTap: () => _onDigit(d),
                          size: dotSize,
                        ),
                      _supportBio
                          ? _IconButton(
                              icon: LucideIcons.fingerprint,
                              onTap: _tryBiometric,
                              size: dotSize,
                            )
                          : SizedBox(width: dotSize, height: dotSize),
                      _NumButton(
                        label: '0',
                        onTap: () => _onDigit('0'),
                        size: dotSize,
                      ),
                      _IconButton(
                        icon: LucideIcons.delete,
                        onTap: _onBackspace,
                        size: dotSize,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _error == null ? 0 : 1,
                  child: Text(
                    _error ?? ' ',
                    style: theme.typography.bodySmall.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NumButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double size;

  const _NumButton({
    required this.label,
    required this.onTap,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Material(
      color: theme.colors.surfaceContainerHighest,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Text(label, style: theme.typography.displaySmall.onSurface),
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _IconButton({
    required this.icon,
    required this.onTap,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(icon, size: 24, color: context.theme.colors.onSurface),
      ),
    );
  }
}
