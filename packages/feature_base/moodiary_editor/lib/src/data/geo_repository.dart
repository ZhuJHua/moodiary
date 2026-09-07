import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:latlong2/latlong.dart';
import 'package:moodiary_editor/src/data/model/geo.dart';
import 'package:moodiary_editor/src/data/qweather_config.dart';
import 'package:moodiary_http/moodiary_http.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:mui/mui.dart';

enum GeoFailure {
  notConfigured,

  permissionDenied,

  permissionDeniedForever,

  serviceOff,

  lookupFailed,
}

GeoFailure _geoFailureOf(LocationFailure? failure) => switch (failure) {
  LocationFailure.permissionDenied => GeoFailure.permissionDenied,
  LocationFailure.permissionDeniedForever => GeoFailure.permissionDeniedForever,
  LocationFailure.serviceOff => GeoFailure.serviceOff,
  _ => GeoFailure.lookupFailed,
};

typedef GeoResult = ({String? name, LatLng? coords, GeoFailure? failure});

typedef CoordinatesResult = ({LatLng? coords, GeoFailure? failure});

@lazySingleton
class GeoRepository {
  GeoRepository(this._http);

  final IHttpClient _http;

  Future<CoordinatesResult> currentCoordinates() async {
    final result = await LocationService.current();
    final lat = result.latitude;
    final lon = result.longitude;
    if (lat == null || lon == null) {
      return (coords: null, failure: _geoFailureOf(result.failure));
    }
    return (coords: LatLng(lat, lon), failure: null);
  }

  Future<GeoResult> getGeo(BuildContext context, {LatLng? coords}) async {
    final credentials = await qweatherCredentials();
    if (credentials == null) {
      return (name: null, coords: null, failure: GeoFailure.notConfigured);
    }
    var at = coords;
    if (at == null) {
      final located = await currentCoordinates();
      at = located.coords;
      if (at == null) {
        return (name: null, coords: null, failure: located.failure);
      }
    }
    if (!context.mounted) {
      return (name: null, coords: null, failure: GeoFailure.lookupFailed);
    }
    final name = await _reverseGeocode(context, at, credentials);
    if (name == null) {
      return (name: null, coords: null, failure: GeoFailure.lookupFailed);
    }
    return (name: name, coords: at, failure: null);
  }

  Future<String?> _reverseGeocode(
    BuildContext context,
    LatLng coords,
    QweatherCredentials credentials,
  ) async {
    final local = Localizations.localeOf(context);
    try {
      final res = await _http.get(
        'https://${credentials.host}/geo/v2/city/lookup',
        query: {
          'location': qweatherLocation(coords),
          'key': credentials.key,
          'lang': local,
        },
      );
      final geo = await compute(
        GeoResponse.fromJson,
        res.data as Map<String, dynamic>,
      );
      final locations = geo.location;
      if (locations == null || locations.isEmpty) return null;
      final city = locations.first;
      return '${city.adm2} ${city.name}';
    } catch (_) {
      return null;
    }
  }
}

// 和风 location 参数只认两位小数精度
String qweatherLocation(LatLng coords) {
  final lon = double.parse(coords.longitude.toStringAsFixed(2));
  final lat = double.parse(coords.latitude.toStringAsFixed(2));
  return '$lon,$lat';
}
