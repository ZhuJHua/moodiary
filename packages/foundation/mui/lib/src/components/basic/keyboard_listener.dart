import 'dart:ui';

import 'package:flutter/widgets.dart';

/// 软键盘状态。只有 [KeyboardObserver] 产出它，所以定义就放在这里。
enum KeyboardState { unknown, opening, closing, closed }

class KeyboardObserver with WidgetsBindingObserver {
  final void Function(double height)? onHeightChanged;

  final void Function(KeyboardState state) onStateChanged;

  double _lastHeight = 0;

  KeyboardState _keyboardState = .closed;

  KeyboardObserver({this.onHeightChanged, required this.onStateChanged});

  void start() {
    WidgetsBinding.instance.addObserver(this);
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final height = PlatformDispatcher.instance.views.first.viewInsets.bottom;

      if (height != _lastHeight) {
        onHeightChanged?.call(height);
      }

      if (height > _lastHeight && _keyboardState != .opening) {
        _keyboardState = .opening;
        onStateChanged.call(_keyboardState);
      } else if (height < _lastHeight && _keyboardState != .closing) {
        _keyboardState = .closing;
        onStateChanged.call(_keyboardState);
      }

      if (height == 0 && _keyboardState != .closed) {
        _keyboardState = .closed;
        onStateChanged.call(_keyboardState);
      }

      _lastHeight = height;
    });
  }
}
