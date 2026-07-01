import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:moodiary_core/moodiary_core.dart';

class KeyboardObserver with WidgetsBindingObserver {
  final void Function(double height)? onHeightChanged;

  final void Function(KeyboardState state) onStateChanged;

  double _lastHeight = 0;

  KeyboardState _keyboardState = KeyboardState.closed;

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

      if (height > _lastHeight && _keyboardState != KeyboardState.opening) {
        _keyboardState = KeyboardState.opening;
        onStateChanged.call(_keyboardState);
      } else if (height < _lastHeight &&
          _keyboardState != KeyboardState.closing) {
        _keyboardState = KeyboardState.closing;
        onStateChanged.call(_keyboardState);
      }

      if (height == 0 && _keyboardState != KeyboardState.closed) {
        _keyboardState = KeyboardState.closed;
        onStateChanged.call(_keyboardState);
      }

      _lastHeight = height;
    });
  }
}
