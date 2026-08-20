import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_editor/src/data/model/geo.dart';
import 'package:moodiary_http/moodiary_http.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

/// 和风天气「地理位置」仓储：定位 + 反查城市，返回 `[lat, lng, "adm2 name"]`。
class GeoRepository {
  GeoRepository(this._http);

  factory GeoRepository.get() => _instance;

  static final GeoRepository _instance = GeoRepository(.get());

  final IHttpClient _http;

  Future<List<String>?> getGeo(BuildContext context) async {
    Position? position;
    var permission = await Geolocator.checkPermission();
    if (permission == .denied) {
      permission = await Geolocator.requestPermission();
      if (permission == .denied && context.mounted) {
        toast.info(message: context.l10n.editor.noticeEnableLocation);
        return null;
      }
      if (permission == .deniedForever && context.mounted) {
        toast.info(message: context.l10n.editor.noticeEnableLocation2);
        return null;
      }
    }
    if (await Geolocator.isLocationServiceEnabled()) {
      position = await Geolocator.getLastKnownPosition(
        forceAndroidLocationManager: true,
      );
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(forceLocationManager: true),
      );
    }
    if (position != null && context.mounted) {
      // key / host 任一未配置就短路（与 WeatherRepository 同因）。
      final host = MoodiaryKVs.qweatherApiHost.get();
      final key = await MoodiarySecureKVs.qweatherKey.get();
      if (host == null || host.isEmpty || key == null || key.isEmpty) {
        return null;
      }
      if (!context.mounted) return null;
      final local = Localizations.localeOf(context);
      final parameters = {
        'location':
            '${double.parse(position.longitude.toStringAsFixed(2))},${double.parse(position.latitude.toStringAsFixed(2))}',
        'key': key,
        'lang': local,
      };
      final res = await _http.get(
        'https://$host/geo/v2/city/lookup',
        query: parameters,
      );
      final geo = await compute(
        GeoResponse.fromJson,
        res.data as Map<String, dynamic>,
      );
      if (geo.location != null && geo.location!.isNotEmpty) {
        final city = geo.location!.first;
        return [
          position.latitude.toString(),
          position.longitude.toString(),
          '${city.adm2} ${city.name}',
        ];
      } else {
        return null;
      }
    } else {
      return null;
    }
  }
}
