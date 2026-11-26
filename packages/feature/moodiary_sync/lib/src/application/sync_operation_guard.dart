import 'dart:async';

class SyncOperationGuard {
  final _changes = StreamController<bool>.broadcast();
  Stream<bool> get changes => _changes.stream;
  SyncOperation? _active;
  bool get isBusy => _active != null;

  SyncOperation? tryAcquire() {
    if (isBusy || _changes.isClosed) return null;
    final operation = SyncOperation._(this);
    _active = operation;
    _changes.add(true);
    return operation;
  }

  void _release(SyncOperation operation) {
    operation.checkActive();
    _active = null;
    if (!_changes.isClosed) _changes.add(false);
  }

  Future<void> dispose() => _changes.close();

  Future<T?> tryWithOperation<T>(
    FutureOr<T> Function(SyncOperation) body,
  ) async {
    final operation = tryAcquire();
    if (operation == null) return null;
    try {
      return await body(operation);
    } finally {
      operation.release();
    }
  }

  Future<T?> tryRun<T>(FutureOr<T> Function() body) =>
      tryWithOperation((_) => body());

  Future<T> runExclusive<T>(FutureOr<T> Function() body) async {
    final operation = tryAcquire();
    if (operation == null) {
      throw StateError('A sync operation is already running');
    }
    try {
      return await body();
    } finally {
      operation.release();
    }
  }
}

final class SyncOperation {
  SyncOperation._(this._guard);
  final SyncOperationGuard _guard;

  void checkActive([SyncOperationGuard? owner]) {
    if (!identical(_guard._active, this) ||
        (owner != null && !identical(_guard, owner))) {
      throw StateError('Expired sync operation');
    }
  }

  void release() {
    _guard._release(this);
  }
}
