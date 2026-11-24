import 'package:moodiary_native/moodiary_native.dart';

enum LocationFailure {
  permissionDenied,

  permissionDeniedForever,

  serviceOff,

  unavailable,
}

typedef LocationResult = ({
  double? latitude,
  double? longitude,
  LocationFailure? failure,
});

abstract final class LocationService {
  static const Duration _freshEnough = Duration(minutes: 10);

  static const Duration _maxFixAge = Duration(hours: 1);

  static const Duration _fixTimeout = Duration(seconds: 20);

  static final LocationApi _api = LocationApi();

  static Future<LocationResult> current({bool precise = false}) async {
    try {
      // Before the permission: with services off iOS reports every app as denied.
      if (!await _api.isServiceEnabled()) {
        return _failed(LocationFailure.serviceOff);
      }
      switch (await _api.requestPermission()) {
        case LocationAuthorization.granted:
          break;
        case LocationAuthorization.denied:
          return _failed(LocationFailure.permissionDenied);
        case LocationAuthorization.deniedForever:
          return _failed(LocationFailure.permissionDeniedForever);
      }
      final cached = await _api.lastKnown();
      if (!precise &&
          cached != null &&
          Duration(milliseconds: cached.ageMillis) < _freshEnough) {
        return _ok(cached);
      }
      final wait = Stopwatch()..start();
      final fresh = await _api.current(precise, _fixTimeout.inMilliseconds);
      wait.stop();
      if (fresh != null &&
          Duration(milliseconds: fresh.ageMillis) < _maxFixAge) {
        return _ok(fresh);
      }
      if (cached != null &&
          Duration(milliseconds: cached.ageMillis) + wait.elapsed <
              _maxFixAge) {
        return _ok(cached);
      }
      return _failed(LocationFailure.unavailable);
    } catch (_) {
      return _failed(LocationFailure.unavailable);
    }
  }

  static LocationResult _ok(LocationFix fix) =>
      (latitude: fix.latitude, longitude: fix.longitude, failure: null);

  static LocationResult _failed(LocationFailure failure) =>
      (latitude: null, longitude: null, failure: failure);
}
