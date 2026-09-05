import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:latlong2/latlong.dart';
import 'package:moodiary_editor/src/data/geo_repository.dart';
import 'package:moodiary_editor/src/data/model/weather.dart';
import 'package:moodiary_editor/src/data/qweather_config.dart';
import 'package:moodiary_http/moodiary_http.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:mui/mui.dart';

typedef WeatherResult = ({DiaryWeather? weather, GeoFailure? failure});

/// 和风「实时天气」仓储：按经纬度取 [DiaryWeather]。
///
/// 入参是**裸坐标**，不是 [DiaryPosition] —— 天气与位置是两条互不相干的链路，
/// 取天气既不需要地名、也不该顺手把位置写进日记。
@lazySingleton
class WeatherRepository {
  WeatherRepository(this._http);

  final IHttpClient _http;

  Future<WeatherResult> getWeather({
    required BuildContext context,
    required LatLng coords,
  }) async {
    final credentials = await qweatherCredentials();
    if (credentials == null) {
      return (weather: null, failure: GeoFailure.notConfigured);
    }
    if (!context.mounted) {
      return (weather: null, failure: GeoFailure.lookupFailed);
    }
    final local = Localizations.localeOf(context);
    final res = await _http.get(
      'https://${credentials.host}/v7/weather/now',
      query: {
        'location': qweatherLocation(coords),
        'key': credentials.key,
        'lang': local,
      },
    );
    final weather = await compute(
      WeatherResponse.fromJson,
      res.data as Map<String, dynamic>,
    );
    final now = weather.now;
    final icon = now?.icon;
    final text = now?.text;
    if (icon == null || text == null) {
      return (weather: null, failure: GeoFailure.lookupFailed);
    }
    return (
      weather: DiaryWeather(icon: icon, temp: now?.temp, text: text),
      failure: null,
    );
  }
}
