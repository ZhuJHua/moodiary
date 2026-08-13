import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_editor/src/data/model/weather.dart';
import 'package:mui/mui.dart';

/// 和风天气「实时天气」仓储：按经纬度取 `[icon, temp, text]` 三元组。
class WeatherRepository {
  WeatherRepository(this._http);

  factory WeatherRepository.get() => _instance;

  static final WeatherRepository _instance = WeatherRepository(.get());

  final IHttpClient _http;

  Future<List<String>?> getWeather({
    required BuildContext context,
    required LatLng position,
  }) async {
    final local = Localizations.localeOf(context);
    final parameters = {
      'location':
          '${double.parse(position.longitude.toStringAsFixed(2))},${double.parse(position.latitude.toStringAsFixed(2))}',
      'key': MoodiaryKVs.qweatherKey.get(),
      'lang': local,
    };
    final res = await _http.get(
      'https://${MoodiaryKVs.qweatherApiHost.get()}/v7/weather/now',
      query: parameters,
    );
    final weather = await compute(
      WeatherResponse.fromJson,
      res.data as Map<String, dynamic>,
    );
    if (weather.now != null) {
      return [weather.now!.icon!, weather.now!.temp!, weather.now!.text!];
    } else {
      return null;
    }
  }
}
