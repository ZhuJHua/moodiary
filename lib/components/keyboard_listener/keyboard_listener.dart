import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:moodiary/common/values/keyboard_state.dart';

class KeyboardObserver with WidgetsBindingObserver {
  /// 键盘高度变化回调
  final void Function(double height)? onHeightChanged;

  /// 键盘状态变化回调
  final void Function(KeyboardState state) onStateChanged;

  /// 上一次的键盘高度
  double _lastHeight = 0;

  /// 当前键盘状态
  KeyboardState _keyboardState = KeyboardState.closed;

  KeyboardObserver({this.onHeightChanged, required this.onStateChanged});

  /// 开始监听
  void start() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// 停止监听
  void stop() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 当前键盘高度
      final height = PlatformDispatcher.instance.views.first.viewInsets.bottom;

      // 通知键盘高度变化
      if (height != _lastHeight) {
        onHeightChanged?.call(height);
      }

      // 检测键盘状态变化
      if (height > _lastHeight && _keyboardState != KeyboardState.opening) {
        _keyboardState = KeyboardState.opening;
        onStateChanged.call(_keyboardState);
      } else if (height < _lastHeight &&
          _keyboardState != KeyboardState.closing) {
        _keyboardState = KeyboardState.closing;
        onStateChanged.call(_keyboardState);
      }

      // 如果键盘完全关闭
      if (height == 0 && _keyboardState != KeyboardState.closed) {
        _keyboardState = KeyboardState.closed;
        onStateChanged.call(_keyboardState);
      }

      // 更新最后的高度
      _lastHeight = height;
    });
  }
}
