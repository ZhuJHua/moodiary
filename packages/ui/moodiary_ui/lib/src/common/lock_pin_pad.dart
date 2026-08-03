import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 密码长度 —— 与启动解锁页对齐。
const int kPinLength = 4;

/// 命令式句柄：外层驱动键盘清空 / 抖动。
class LockPinPadController {
  _LockPinPadState? _state;

  void _attach(_LockPinPadState state) => _state = state;

  void _detach(_LockPinPadState state) {
    if (identical(_state, state)) _state = null;
  }

  /// 正常清空，不抖动。
  void clear() => _state?._clear();

  /// 触觉 + 抖动 + 清空（密码错误 / 两次不一致）。
  void reject() => _state?._reject();
}

class LockPinPad extends StatefulWidget {
  final String title;

  final String? error;

  final bool showBiometric;

  final VoidCallback? onBiometric;

  final ValueChanged<String> onCompleted;

  final bool enabled;

  final LockPinPadController? controller;

  const LockPinPad({
    super.key,
    required this.title,
    required this.onCompleted,
    this.error,
    this.showBiometric = false,
    this.onBiometric,
    this.enabled = true,
    this.controller,
  });

  @override
  State<LockPinPad> createState() => _LockPinPadState();
}

class _LockPinPadState extends State<LockPinPad>
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

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(LockPinPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _clear() {
    if (!mounted) return;
    setState(() => _pin = '');
  }

  void _reject() {
    HapticFeedback.mediumImpact();
    _shakeCtrl.forward(from: 0).whenComplete(() {
      if (mounted) _shakeCtrl.reverse();
    });
    _clear();
  }

  void _onDigit(String d) {
    if (!widget.enabled || _pin.length >= kPinLength) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += d);
    if (_pin.length == kPinLength) {
      final pin = _pin;
      // 让最后一个圆点动画完成再回调校验。
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) widget.onCompleted(pin);
      });
    }
  }

  void _onBackspace() {
    if (!widget.enabled || _pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
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
    final scheme = context.colorScheme;
    final dotSize =
        (context.textTheme.displayLarge?.fontSize ?? 57) *
        (context.textTheme.displayLarge?.height ?? 1.12);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.title, style: context.textTheme.titleMedium),
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(kPinLength, (i) {
              final filled = i < _pin.length;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
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
            padding: EdgeInsets.zero,
            children: [
              for (final d in const ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
                _NumButton(label: d, onTap: () => _onDigit(d), size: dotSize),
              widget.showBiometric
                  ? _IconButton(
                      icon: LucideIcons.fingerprint,
                      onTap: widget.onBiometric ?? () {},
                      size: dotSize,
                    )
                  : SizedBox(width: dotSize, height: dotSize),
              _NumButton(label: '0', onTap: () => _onDigit('0'), size: dotSize),
              _IconButton(
                icon: LucideIcons.delete,
                onTap: _onBackspace,
                size: dotSize,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: widget.error == null ? 0 : 1,
          child: Text(
            widget.error ?? ' ',
            style: context.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ),
      ],
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
    final scheme = context.colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Text(label, style: context.textTheme.displaySmall),
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
        child: Icon(icon, size: 24),
      ),
    );
  }
}
