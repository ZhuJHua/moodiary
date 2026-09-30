import 'package:flutter/widgets.dart';

mixin SoftKeyboardObserver<T extends StatefulWidget> on State<T> {
  late final _SoftKeyboardMetrics _softKeyboard = _SoftKeyboardMetrics(
    didChangeSoftKeyboardVisibility,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_softKeyboard);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_softKeyboard);
    super.dispose();
  }

  void didChangeSoftKeyboardVisibility(bool visible);
}

class _SoftKeyboardMetrics with WidgetsBindingObserver {
  final ValueChanged<bool> _onChange;

  bool _visible = _read();

  _SoftKeyboardMetrics(this._onChange);

  static bool _read() {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    return (view?.viewInsets.bottom ?? 0) > 0;
  }

  @override
  void didChangeMetrics() {
    final visible = _read();
    if (visible == _visible) return;
    _visible = visible;
    _onChange(visible);
  }
}
