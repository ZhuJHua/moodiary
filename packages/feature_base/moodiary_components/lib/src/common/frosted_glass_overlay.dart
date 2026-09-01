import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:mui/mui.dart';

/// 后台隐私保护遮罩。**包住整个 App**，内部自建 `Overlay` 把遮罩作为独立 entry
/// 叠在 [child] 之上 —— 调用方不需要自己摆 `Stack`，也不需要传 key 或回调。
///
/// 用 Overlay 而不是 Stack 的理由：遮罩与 App 是两条互不影响的渲染分支，
/// App 侧重建不会带着遮罩一起重建，遮罩每帧的模糊动画也不会让 App 重新 layout。
/// `FlutterSmartDialog.init()` 内部用的是同一套做法。
///
/// 仅当 [MoodiaryKVs.backendPrivacy] 为 true 时起效；关掉时遮罩恒为透明且不吃点击。
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
    // entry 的 builder 闭包捕获的是**旧**的 widget.child，父级换 child 时
    // 必须显式标脏，否则整个 App 分支停在上一帧。
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
    // entry 按列表顺序自下而上：App 在下，遮罩在上。
    return Overlay(initialEntries: [_appEntry, _maskEntry]);
  }
}
