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
    // key / host 任一未配置就短路：和风的 API Host 是 per-key 专属的（2.8.0 新增配置，
    // 升级用户为空），拼出来的 `https://null/...` 只会白打一发必败请求。
    final host = MoodiaryKVs.qweatherApiHost.get();
    final key = MoodiaryKVs.qweatherKey.get();
    if (host == null || host.isEmpty || key == null || key.isEmpty) {
      return null;
    }
    final local = Localizations.localeOf(context);
    final parameters = {
      'location':
          '${double.parse(position.longitude.toStringAsFixed(2))},${double.parse(position.latitude.toStringAsFixed(2))}',
      'key': key,
      'lang': local,
    };
    final res = await _http.get(
      'https://$host/v7/weather/now',
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
