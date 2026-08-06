import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 平板短边阈值（dp）：短边 ≥ 此值视为平板，放开旋转。仅用于方向锁定，与 UI 布局无关。
const double _kTabletShortestSideThreshold = 600.0;

/// 按物理短边决定竖屏锁定：< 阈值锁竖屏，否则四向放开（平板 / 折叠屏展开态）。
/// 桌面端由窗口控制方向，始终放开。监听 [didChangeMetrics] 重评估，折叠屏展开时自动切换。
class _OrientationLockObserver extends WidgetsBindingObserver {
  DeviceOrientationPolicy? _lastApplied;

  /// 临时放开期间不让 metrics 回调抢回方向（转屏本身就会触发 didChangeMetrics）。
  int _overrides = 0;

  @override
  void didChangeMetrics() {
    if (_overrides > 0) return;
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
      .portraitOnly => const [DeviceOrientation.portraitUp],
      .unrestricted => const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    });
  }
}

enum DeviceOrientationPolicy { portraitOnly, unrestricted }

/// 按内容宽高比选全屏方向：宽 > 高 锁横（两个横向都给，用户左右手持都行），否则锁竖。
/// 正方形按竖处理 —— 手机自然持握是竖的，1:1 放进横屏两侧留白过大。
List<DeviceOrientation> fullscreenOrientationsFor(double aspectRatio) =>
    aspectRatio > 1.0
    ? const [.landscapeLeft, .landscapeRight]
    : const [.portraitUp];

final _OrientationLockObserver _orientationObserver =
    _OrientationLockObserver();
bool _orientationObserverRegistered = false;

/// 启动时调用一次：注册 metrics 监听器并立即应用一次策略。
void applyDeviceOrientationLock() {
  if (!_orientationObserverRegistered) {
    WidgetsBinding.instance.addObserver(_orientationObserver);
    _orientationObserverRegistered = true;
  }
  _orientationObserver._evaluateAndApply();
}

/// 恢复函数。返回值 = **这一次调用是否真的把全局策略应用回去了**（嵌套计数归零才会）。
/// 调用方据此决定要不要去等「屏幕真的转回来」—— 计数没归零时一个方向请求都没发出去，
/// 傻等只会吃满超时。
typedef OrientationOverrideRelease = bool Function();

/// 当前全局方向策略。平板 / 折叠屏展开态是 unrestricted（放开四向），此时任何
/// 「锁定 → 等它转回来」的编排都不成立：系统会按物理姿态自己转，等不到确定终态。
DeviceOrientationPolicy currentOrientationPolicy() =>
    _orientationObserver._lastApplied ?? .portraitOnly;

/// 临时把方向锁到 [orientations]（视频全屏按片子比例锁横 / 锁竖），返回恢复函数；
/// 嵌套安全（计数到 0 才恢复全局策略）。
///
/// 必须走这里，不要直接调 [SystemChrome.setPreferredOrientations] —— 观察者用
/// `_lastApplied` 去重，外部绕过它改了方向之后策略并未变化，竖屏锁就再也应用不回来了。
///
/// 平台前提：iOS 只能转到 Info.plist 的 `UISupportedInterfaceOrientations` 声明过的方向，
/// 未声明的方向这里会静默无效（Android 走 setRequestedOrientation，可越过系统旋转锁定）。
OrientationOverrideRelease lockOrientationsTemporarily(
  List<DeviceOrientation> orientations,
) {
  final observer = _orientationObserver;
  observer._overrides += 1;
  SystemChrome.setPreferredOrientations(orientations);
  var released = false;
  return () {
    if (released) return false;
    released = true;
    observer._overrides -= 1;
    if (observer._overrides > 0) return false;
    // 去重状态清掉，否则策略「未变化」会让恢复成为空操作。
    observer._lastApplied = null;
    observer._evaluateAndApply();
    return true;
  };
}

/// 沉浸模式（藏起状态栏与导航栏），返回恢复函数；嵌套安全。
///
/// **恢复不能只调 [SystemUiMode.edgeToEdge]。** 全 app 平时就跑在 edgeToEdge 里，
/// 再设一次对「栏的显隐」是空操作，于是被沉浸模式藏掉的栏再也不出现 —— 整个 app 从此没有
/// 状态栏。必须先用 manual 把两条栏点亮，再回到 edgeToEdge。
///
/// 关于「targetSdk 36 上还能不能藏」：Flutter 的 [SystemUiMode] 文档写着「Android 系统会
/// 忽略这个值」，那句话过重了。Android 16 的行为变更只规定「边到边不能再退出」，并没有把
/// `View.setSystemUiVisibility` 的那几个 flag 变成空操作，而引擎里 immersiveSticky 正是用
/// 它们实现的；实测（含 flutter 3.44 + targetSdk 36 的其它 app）**藏得掉，坏的只有恢复这条路**。
ImmersiveOverrideRelease enterImmersiveTemporarily() {
  _immersiveOverrides += 1;
  SystemChrome.setEnabledSystemUIMode(.immersiveSticky);
  var released = false;
  return () {
    if (released) return;
    released = true;
    _immersiveOverrides -= 1;
    if (_immersiveOverrides > 0) return;
    SystemChrome.setEnabledSystemUIMode(
      .manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setEnabledSystemUIMode(.edgeToEdge);
  };
}

typedef ImmersiveOverrideRelease = void Function();

int _immersiveOverrides = 0;

@visibleForTesting
void resetImmersiveOverridesForTest() => _immersiveOverrides = 0;
