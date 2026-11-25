import 'dart:async';

class SyncOperationGuard {
  bool _busy = false;
  bool get isBusy => _busy;

  Future<T?> tryRun<T>(FutureOr<T> Function() operation) async {
    if (_busy) return null;
    return runExclusive(operation);
  }

  Future<T> runExclusive<T>(FutureOr<T> Function() operation) async {
    if (_busy) throw StateError('A sync operation is already running');
    _busy = true;
    try {
      return await operation();
    } finally {
      _busy = false;
    }
  }
}
