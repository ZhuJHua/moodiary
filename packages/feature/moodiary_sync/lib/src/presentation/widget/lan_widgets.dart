import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moodiary_core/moodiary_core.dart';

String lanFmtBytes(int bytes) {
  final unit = FileUtil.bytesToUnits(bytes);
  return '${unit['size']} ${unit['unit']}';
}

/// 雷达脉冲：中心圆形图标，外圈周期性扩散渐隐。[active] 为 false 时只留静止中心。
class LanRipple extends StatefulWidget {
  final double size;
  final Widget child;
  final bool active;
  final Color? color;

  const LanRipple({
    super.key,
    required this.size,
    required this.child,
    this.active = true,
    this.color,
  });

  @override
  State<LanRipple> createState() => _LanRippleState();
}

class _LanRippleState extends State<LanRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(LanRipple oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.colorScheme.primary;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => CustomPaint(
          painter: _RipplePainter(
            progress: _controller.value,
            color: color,
            active: widget.active,
          ),
          child: child,
        ),
        child: Center(
          child: Container(
            width: widget.size * 0.42,
            height: widget.size * 0.42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: .14),
            ),
            child: Center(child: widget.child),
          ),
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool active;

  const _RipplePainter({
    required this.progress,
    required this.color,
    required this.active,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!active) return;
    final center = size.center(Offset.zero);
    final minRadius = size.width * 0.21;
    final maxRadius = size.width * 0.5;
    for (var i = 0; i < 3; i++) {
      final t = (progress + i / 3) % 1;
      final radius = minRadius + (maxRadius - minRadius) * t;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: (1 - t) * .35);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.active != active ||
      oldDelegate.color != color;
}

/// 六格数字盒（展示态）。[onTap] 常用于整体复制。
class LanPinBoxes extends StatelessWidget {
  final String pin;
  final VoidCallback? onTap;

  const LanPinBoxes({super.key, required this.pin, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 6; i++) ...[
            if (i == 3) const SizedBox(width: 14),
            Container(
              width: 44,
              height: 56,
              margin: EdgeInsets.only(left: i == 0 || i == 3 ? 0 : 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  i < pin.length ? pin[i] : '',
                  style: context.textTheme.headlineMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 六格数字输入（OTP 样式）：隐形 [TextField] 收键盘输入，上层格子只负责展示。
class LanPinInput extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;

  const LanPinInput({super.key, required this.controller, this.enabled = true});

  @override
  State<LanPinInput> createState() => _LanPinInputState();
}

class _LanPinInputState extends State<LanPinInput> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    _focusNode.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final text = widget.controller.text;
    final activeIndex = text.length.clamp(0, 5);
    return SizedBox(
      height: 56,
      child: Stack(
        children: [
          // 铺满整块区域的隐形输入框：点任意格子都聚焦到它。
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                enableInteractiveSelection: false,
                showCursor: false,
                autocorrect: false,
              ),
            ),
          ),
          IgnorePointer(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 6; i++) ...[
                  if (i == 3) const SizedBox(width: 14),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44,
                    height: 56,
                    margin: EdgeInsets.only(left: i == 0 || i == 3 ? 0 : 8),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        width: 2,
                        color:
                            widget.enabled &&
                                _focusNode.hasFocus &&
                                i == activeIndex
                            ? scheme.primary
                            : Colors.transparent,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        i < text.length ? text[i] : '',
                        style: context.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
