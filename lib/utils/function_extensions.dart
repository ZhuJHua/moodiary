import 'dart:async';
import 'dart:ui';

// Function extensions to add throttling and debouncing capabilities
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

// FunctionProxy class to implement throttling and debouncing
class FunctionProxy {
  static final Map<int, bool> _throttleMap = {};
  static final Map<int, Timer> _debounceMap = {};
  final Function target;
  final int timeout;

  FunctionProxy(this.target, {int? timeout}) : timeout = timeout ?? 500;

  // Throttle function to limit the execution rate
  void throttle() async {
    int key = target.hashCode;
    bool canExecute = _throttleMap[key] ?? true;
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

  // Throttle function with a specified timeout
  void throttleWithTimeout() {
    int key = target.hashCode;
    bool canExecute = _throttleMap[key] ?? true;
    if (canExecute) {
      _throttleMap[key] = false;
      Timer(Duration(milliseconds: timeout), () {
        _throttleMap.remove(key);
      });
      target();
    }
  }

  // Debounce function to delay execution until after a specified period
  void debounce() {
    int key = target.hashCode;
    _debounceMap[key]?.cancel();
    _debounceMap[key] = Timer(Duration(milliseconds: timeout), () {
      _debounceMap.remove(key);
      target();
    });
  }
}
