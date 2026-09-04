import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:latlong2/latlong.dart';
import 'package:moodiary_editor/src/data/geo_repository.dart';
import 'package:moodiary_editor/src/data/model/weather.dart';
import 'package:moodiary_http/moodiary_http.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:mui/mui.dart';

/// 和风天气「实时天气」仓储：按经纬度取 [DiaryWeather]。
@lazySingleton
class WeatherRepository {
  WeatherRepository(this._http);

  final IHttpClient _http;

  Future<({DiaryWeather? weather, GeoFailure? failure})> getWeather({
    required BuildContext context,
    required LatLng position,
  }) async {
    // key / host 任一未配置就短路：和风的 API Host 是 per-key 专属的（2.8.0 新增配置，
    // 升级用户为空），拼出来的 `https://null/...` 只会白打一发必败请求。
    final host = MoodiaryKVs.qweatherApiHost.get();
    final key = await MoodiarySecureKVs.qweatherKey.get();
    if (host == null || host.isEmpty || key == null || key.isEmpty) {
      return (weather: null, failure: GeoFailure.notConfigured);
    }
    if (!context.mounted) {
      return (weather: null, failure: GeoFailure.lookupFailed);
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
    final now = weather.now;
    if (now == null) return (weather: null, failure: GeoFailure.lookupFailed);
    return (
      weather: DiaryWeather(icon: now.icon!, temp: now.temp!, text: now.text!),
      failure: null,
    );
  }
}
