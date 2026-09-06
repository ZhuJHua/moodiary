import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:mui/mui.dart';

class FrostedGlassOverlayComponent extends StatefulWidget {
  const FrostedGlassOverlayComponent({super.key, required this.child});

  final Widget child;

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

  late final OverlayEntry _appEntry = OverlayEntry(
    builder: (_) => widget.child,
  );

  late final OverlayEntry _maskEntry = OverlayEntry(builder: (_) => _mask());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant FrostedGlassOverlayComponent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // OverlayEntry 的 builder 闭包捕获旧值，child 变化需显式 markNeedsBuild
    if (widget.child != oldWidget.child) _appEntry.markNeedsBuild();
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

  Widget _mask() => AnimatedBuilder(
    animation: _animationController,
    builder: (context, _) => Positioned.fill(
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
    ),
  );

  @override
  Widget build(BuildContext context) {
    // OverlayEntry 列表顺序即层叠顺序，App 在下、遮罩在上
    return Overlay(initialEntries: [_appEntry, _maskEntry]);
  }
}
