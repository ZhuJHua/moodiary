import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:latlong2/latlong.dart';
import 'package:moodiary_editor/src/data/model/geo.dart';
import 'package:moodiary_editor/src/data/qweather_config.dart';
import 'package:moodiary_http/moodiary_http.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:mui/mui.dart';

/// 取位置 / 天气失败的原因。仓储只判因、不弹提示——同一个原因在编辑页要给用户看，
/// 「保存时自动获取」则必须静默（用户没主动点，不该被弹窗打断）。
enum GeoFailure {
  /// 和风天气未配置（key / host 缺一）。天气与「自动获取位置」（反查地名）两条
  /// 链路都判它，且判在权限请求之前——没配 key 就不该先被要一遍定位权限。
  /// 常用地点那条链路不经过这里：坐标来自 geolocator，一个 key 都不用。
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

/// [LocationFailure] → [GeoFailure]。定位层不认识「没配和风」，故是全射。
GeoFailure geoFailureOf(LocationFailure? failure) => switch (failure) {
  LocationFailure.permissionDenied => GeoFailure.permissionDenied,
  LocationFailure.permissionDeniedForever => GeoFailure.permissionDeniedForever,
  LocationFailure.serviceOff => GeoFailure.serviceOff,
  _ => GeoFailure.lookupFailed,
};

/// 和风反查的结果：行政区名 + 查询时的坐标，或失败原因。
typedef GeoResult = ({String? name, LatLng? coords, GeoFailure? failure});

/// 一次定位的结果：坐标或失败原因。
typedef CoordinatesResult = ({LatLng? coords, GeoFailure? failure});

/// 定位 → 和风反查地名。
///
/// 坐标本身来自 [LocationService]（零 API key）；本类只负责**和风那一级**的名字。
/// 常用地点的就近匹配不在这里——那是页面层拿 `PlaceMatching.matchAt` 做的事，
/// 两级各走各的开关（`autoNearestPlace` / `autoPosition`），互不知道对方。
/// 天气链路只用 [currentCoordinates]，**不经过本类的任何写入**。
@lazySingleton
class GeoRepository {
  GeoRepository(this._http);

  final IHttpClient _http;

  /// 当前坐标。只需要定位权限与系统定位服务。
  Future<CoordinatesResult> currentCoordinates() async {
    final result = await LocationService.current();
    final lat = result.latitude;
    final lon = result.longitude;
    if (lat == null || lon == null) {
      return (coords: null, failure: geoFailureOf(result.failure));
    }
    return (coords: LatLng(lat, lon), failure: null);
  }

  /// 定位（或用传入的 [coords]）+ 和风反查 → 行政区名。
  ///
  /// 反查不到名字就是失败，**不落裸坐标**：这条链路的产出是「地名」，调用方拿它去
  /// 找 / 建常用地点。
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

  /// 和风反查城市名（`adm2 name`，如「杭州市 西湖区」）；查不到返回 null。
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

/// 和风的 `location` 参数：`经度,纬度`，各保留两位小数（它只认这个精度）。
String qweatherLocation(LatLng coords) {
  final lon = double.parse(coords.longitude.toStringAsFixed(2));
  final lat = double.parse(coords.latitude.toStringAsFixed(2));
  return '$lon,$lat';
}
