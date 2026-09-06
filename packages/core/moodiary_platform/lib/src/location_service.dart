import 'dart:async';

import 'package:geolocator/geolocator.dart';

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

  static const Duration _fixTimeout = Duration(seconds: 20);

  static Future<LocationResult> current({bool precise = false}) async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return _failed(LocationFailure.permissionDenied);
    }
    if (permission == LocationPermission.deniedForever) {
      return _failed(LocationFailure.permissionDeniedForever);
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      return _failed(LocationFailure.serviceOff);
    }
    try {
      final cached = await Geolocator.getLastKnownPosition(
        forceAndroidLocationManager: true,
      );
      if (!precise &&
          cached != null &&
          DateTime.now().difference(cached.timestamp) < _freshEnough) {
        return _ok(cached);
      }
      try {
        final fresh = await Geolocator.getCurrentPosition(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.best,
            forceLocationManager: true,
            timeLimit: _fixTimeout,
          ),
        );
        return _ok(fresh);
      } on TimeoutException {
        if (cached != null) return _ok(cached);
        return _failed(LocationFailure.unavailable);
      }
    } catch (_) {
      return _failed(LocationFailure.unavailable);
    }
  }

  static LocationResult _ok(Position p) =>
      (latitude: p.latitude, longitude: p.longitude, failure: null);

  static LocationResult _failed(LocationFailure failure) =>
      (latitude: null, longitude: null, failure: failure);
}
