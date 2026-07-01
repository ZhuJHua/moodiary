import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

/// 平板短边阈值（dp）：短边 ≥ 此值视为平板，放开旋转。仅用于方向锁定，与 UI 布局无关。
const double _kTabletShortestSideThreshold = 600.0;

/// 按物理短边决定竖屏锁定：< 阈值锁竖屏，否则四向放开（平板 / 折叠屏展开态）。
/// 桌面端由窗口控制方向，始终放开。监听 [didChangeMetrics] 重评估，折叠屏展开时自动切换。
class _OrientationLockObserver extends WidgetsBindingObserver {
  DeviceOrientationPolicy? _lastApplied;

  @override
  void didChangeMetrics() {
    _evaluateAndApply();
  }

  void _evaluateAndApply() {
    final FlutterView view = PlatformDispatcher.instance.views.first;
    final double shortestSideDp =
        view.physicalSize.shortestSide / view.devicePixelRatio;
    final policy = shortestSideDp < _kTabletShortestSideThreshold
        ? DeviceOrientationPolicy.portraitOnly
        : DeviceOrientationPolicy.unrestricted;

    if (policy == _lastApplied) return;
    _lastApplied = policy;
    SystemChrome.setPreferredOrientations(switch (policy) {
      DeviceOrientationPolicy.portraitOnly => const [
        DeviceOrientation.portraitUp,
      ],
      DeviceOrientationPolicy.unrestricted => const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    });
  }
}

enum DeviceOrientationPolicy { portraitOnly, unrestricted }

final _OrientationLockObserver _orientationObserver = _OrientationLockObserver();
bool _orientationObserverRegistered = false;

/// 启动时调用一次：注册 metrics 监听器并立即应用一次策略。
void applyDeviceOrientationLock() {
  if (!_orientationObserverRegistered) {
    WidgetsBinding.instance.addObserver(_orientationObserver);
    _orientationObserverRegistered = true;
  }
  _orientationObserver._evaluateAndApply();
}
