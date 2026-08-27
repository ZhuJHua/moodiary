import 'package:freezed_annotation/freezed_annotation.dart';

part 'diary_meta.freezed.dart';
part 'diary_meta.g.dart';

/// 日记定位。旧模型是 `List<String>` 定长元组（`[纬度, 经度, 地名]`，下标即字段），
/// 2.8.0 起为显式值对象：「没有定位」= null，不再是空数组。
@freezed
abstract class DiaryPosition with _$DiaryPosition {
  const factory DiaryPosition({
    required double latitude,
    required double longitude,

    /// 展示用地名（行政区 + 城市名）。
    required String name,
  }) = _DiaryPosition;

  factory DiaryPosition.fromJson(Map<String, dynamic> json) =>
      _$DiaryPositionFromJson(json);
}

/// 日记天气。旧模型是 `List<String>` 定长元组（`[图标码, 温度, 描述]`）。
/// [temp] 保持字符串：和风返回的就是数字字符串（摄氏度、不带单位），原样存取。
@freezed
abstract class DiaryWeather with _$DiaryWeather {
  const factory DiaryWeather({
    /// 和风天气图标码（如 `"100"`）。
    required String icon,
    required String temp,

    /// 文字描述（如「晴」/「多云」）。
    required String text,
  }) = _DiaryWeather;

  factory DiaryWeather.fromJson(Map<String, dynamic> json) =>
      _$DiaryWeatherFromJson(json);
}
