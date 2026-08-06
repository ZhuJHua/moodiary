import 'package:flutter/material.dart';
import 'package:moodiary_core/moodiary_core.dart';

/// 后台隐私保护遮罩。自给自足：内部监听生命周期、仅当 [MoodiaryKVs.backendPrivacy]
/// 为 true 时启用，放到 Stack 顶层即可，无需传 key 或回调。
class FrostedGlassOverlayComponent extends StatefulWidget {
  const FrostedGlassOverlayComponent({super.key});

  @override
  State<FrostedGlassOverlayComponent> createState() =>
      _FrostedGlassOverlayComponentState();
}

class _FrostedGlassOverlayComponentState
    extends State<FrostedGlassOverlayComponent>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (MoodiaryKVs.backendPrivacy.get() != true) return;
    switch (state) {
      case .inactive:
      case .hidden:
      case .paused:
        _animationController.forward();
      case .resumed:
        _animationController.animateTo(
          0,
          duration: const Duration(milliseconds: 50),
        );
      case .detached:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, _) {
        return Positioned.fill(
          child: IgnorePointer(
            ignoring: _animationController.value == 0,
            child: BackdropFilter(
              filter: .blur(
                sigmaX: 10 * _animationController.value,
                sigmaY: 10 * _animationController.value,
              ),
              enabled: _animationController.value > 0,
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }
}
