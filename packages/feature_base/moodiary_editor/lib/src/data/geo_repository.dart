import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:injectable/injectable.dart';
import 'package:moodiary_editor/src/data/model/geo.dart';
import 'package:moodiary_http/moodiary_http.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:mui/mui.dart';

/// 取位置 / 天气失败的原因。仓储只判因、不弹提示——同一个原因在编辑页要给用户看，
/// 「保存时自动获取」则必须静默（用户没主动点，不该被弹窗打断）。
enum GeoFailure {
  /// 和风天气未配置（key / host 缺一）。位置与天气都走它的接口，故这条要**先于**
  /// 权限检查判定：否则没配 key 的用户只会看到一句「未开启定位权限」，白跑一趟授权。
  notConfigured,

  /// 用户本次拒绝了定位权限。
  permissionDenied,

  /// 定位权限被永久拒绝，只能去系统设置里开。
  permissionDeniedForever,

  /// 系统定位服务（GPS）没开。
  serviceOff,

  /// 请求发出去了，但没拿到可用结果。
  lookupFailed,
}

typedef GeoResult = ({DiaryPosition? position, GeoFailure? failure});

/// 和风天气「地理位置」仓储：定位 + 反查城市，返回 [DiaryPosition]。
@lazySingleton
class GeoRepository {
  GeoRepository(this._http);

  final IHttpClient _http;

  Future<GeoResult> getGeo(BuildContext context) async {
    // key / host 任一未配置就短路（与 WeatherRepository 同因）。放在最前面：定位授权
    // 拿到了也没处用，且失败文案必须说「没配服务」而不是「没给权限」。
    final host = MoodiaryKVs.qweatherApiHost.get();
    final key = await MoodiarySecureKVs.qweatherKey.get();
    if (host == null || host.isEmpty || key == null || key.isEmpty) {
      return (position: null, failure: GeoFailure.notConfigured);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == .denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == .denied) {
      return (position: null, failure: GeoFailure.permissionDenied);
    }
    if (permission == .deniedForever) {
      return (position: null, failure: GeoFailure.permissionDeniedForever);
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      return (position: null, failure: GeoFailure.serviceOff);
    }

    var position = await Geolocator.getLastKnownPosition(
      forceAndroidLocationManager: true,
    );
    position ??= await Geolocator.getCurrentPosition(
      locationSettings: AndroidSettings(forceLocationManager: true),
    );
    if (!context.mounted) {
      return (position: null, failure: GeoFailure.lookupFailed);
    }

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
    final locations = geo.location;
    if (locations == null || locations.isEmpty) {
      return (position: null, failure: GeoFailure.lookupFailed);
    }
    final city = locations.first;
    return (
      position: DiaryPosition(
        latitude: position.latitude,
        longitude: position.longitude,
        name: '${city.adm2} ${city.name}',
      ),
      failure: null,
    );
  }
}
