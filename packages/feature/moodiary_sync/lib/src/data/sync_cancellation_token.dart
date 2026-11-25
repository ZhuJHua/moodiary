class SyncCancellationToken {
  bool _requested = false;
  bool get isRequested => _requested;

  void requestStop() => _requested = true;
}
