import 'dart:async';
import 'dart:ui';

extension FunctionExtensions on Function {
  VoidCallback throttle() {
    return FunctionProxy(this).throttle;
  }

  VoidCallback throttleWithTimeout({int? timeout}) {
    return FunctionProxy(this, timeout: timeout).throttleWithTimeout;
  }

  VoidCallback debounce({int? timeout}) {
    return FunctionProxy(this, timeout: timeout).debounce;
  }
}

class FunctionProxy {
  static final Map<int, bool> _throttleMap = {};
  static final Map<int, Timer> _debounceMap = {};
  final Function target;
  final int timeout;

  FunctionProxy(this.target, {int? timeout}) : timeout = timeout ?? 500;

  void throttle() async {
    final int key = target.hashCode;
    final bool canExecute = _throttleMap[key] ?? true;
    if (canExecute) {
      _throttleMap[key] = false;
      try {
        await target();
      } catch (e) {
        rethrow;
      } finally {
        _throttleMap.remove(key);
      }
    }
  }

  void throttleWithTimeout() {
    final int key = target.hashCode;
    final bool canExecute = _throttleMap[key] ?? true;
    if (canExecute) {
      _throttleMap[key] = false;
      Timer(Duration(milliseconds: timeout), () {
        _throttleMap.remove(key);
      });
      target();
    }
  }

  void debounce() {
    final int key = target.hashCode;
    _debounceMap[key]?.cancel();
    _debounceMap[key] = Timer(Duration(milliseconds: timeout), () {
      _debounceMap.remove(key);
      target();
    });
  }
}
