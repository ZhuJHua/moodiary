import 'package:freezed_annotation/freezed_annotation.dart';

/// JSON 边界统一 UTC（带 `Z` 后缀）：裸 `toIso8601String()` 序列化本地时间不带
/// 时区偏移，另一台不同时区的设备 parse 会把时刻解错。
class UtcDateTimeConverter implements JsonConverter<DateTime, String> {
  const UtcDateTimeConverter();

  @override
  DateTime fromJson(String json) => .parse(json);

  @override
  String toJson(DateTime object) => object.toUtc().toIso8601String();
}
