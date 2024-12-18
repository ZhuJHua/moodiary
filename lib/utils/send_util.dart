class UploadSpeedCalculator {
  final int updateIntervalInMilliseconds;
  DateTime _lastUpdateTime = DateTime.now();
  double _speed = 0.0;
  int _previousSentBytes = 0;

  UploadSpeedCalculator({this.updateIntervalInMilliseconds = 500});

  void updateSpeed(int sent) {
    final currentTime = DateTime.now();
    final timeElapsed = currentTime.difference(_lastUpdateTime).inMilliseconds / 1000;
    if (timeElapsed >= (updateIntervalInMilliseconds / 1000)) {
      final sentSinceLastUpdate = sent - _previousSentBytes;
      _speed = sentSinceLastUpdate / timeElapsed;
      const maxSpeed = 1.0 * 1024 * 1024 * 1024;
      if (_speed > maxSpeed) {
        _speed = maxSpeed;
      }
      _previousSentBytes = sent;
      _lastUpdateTime = currentTime;
    }
  }

  double getSpeed() {
    return _speed;
  }
}
