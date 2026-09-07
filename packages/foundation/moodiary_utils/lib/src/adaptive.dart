import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const double _kTabletShortestSideThreshold = 600.0;

class _OrientationLockObserver extends WidgetsBindingObserver {
  DeviceOrientationPolicy? _lastApplied;

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

List<DeviceOrientation> fullscreenOrientationsFor(double aspectRatio) =>
    aspectRatio > 1.0
    ? const [.landscapeLeft, .landscapeRight]
    : const [.portraitUp];

final _OrientationLockObserver _orientationObserver =
    _OrientationLockObserver();
bool _orientationObserverRegistered = false;

void applyDeviceOrientationLock() {
  if (!_orientationObserverRegistered) {
    WidgetsBinding.instance.addObserver(_orientationObserver);
    _orientationObserverRegistered = true;
  }
  _orientationObserver._evaluateAndApply();
}

typedef OrientationOverrideRelease = bool Function();

DeviceOrientationPolicy currentOrientationPolicy() =>
    _orientationObserver._lastApplied ?? .portraitOnly;

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
    observer._lastApplied = null;
    observer._evaluateAndApply();
    return true;
  };
}

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
