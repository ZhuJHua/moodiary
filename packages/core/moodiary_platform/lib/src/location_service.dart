import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// 取坐标失败的原因。**没有「未配置服务」这一档** —— 定位一个 API key 都不用，
/// 那是上层反查地名才需要的事。
enum LocationFailure {
  /// 用户本次拒绝了定位权限。
  permissionDenied,

  /// 定位权限被永久拒绝，只能去系统设置里开。
  permissionDeniedForever,

  /// 系统定位服务（GPS）没开。
  serviceOff,

  /// 权限与服务都有，但没拿到坐标（超时、驱动异常等）。
  unavailable,
}

/// 一次定位的结果：坐标或失败原因，两者恰好有一个非空。
typedef LocationResult = ({
  double? latitude,
  double? longitude,
  LocationFailure? failure,
});

/// 设备定位。**只包 geolocator，不认识任何第三方地理服务** —— 坐标 → 地名是上层
/// 的事（常用地点就近匹配、和风反查），它们各自决定要不要、以及用什么去起名字。
///
/// 这条边是有意画的：早先取坐标被和风的 key 挡在门外，等于把一个不需要注册第三方
/// 账号的能力做成了要注册。
abstract final class LocationService {
  /// 系统缓存定位多久以内算「还能用」。写日记时在哪这个精度要求，十分钟内的
  /// 缓存完全够用；再旧就可能是上一个地方了，拿它去匹配常用地点会记错。
  static const Duration _freshEnough = Duration(minutes: 10);

  /// 等一次新鲜定位的上限。室内冷启动 GPS 可能一直等不到，超时退回缓存。
  static const Duration _fixTimeout = Duration(seconds: 20);

  /// 当前坐标，精度 [LocationAccuracy.best]。
  ///
  /// 默认先看系统缓存（`getLastKnownPosition`）：十分钟内的直接用——自动记录跑在
  /// 保存路径上，等一次冷定位会把保存拖到秒级；再旧就等一次新鲜的。
  /// [precise] = 不看缓存、只要新鲜定位（存常用地点用：要的是这个点本身），
  /// 超时才退回缓存。
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
