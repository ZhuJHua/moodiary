import 'package:freezed_annotation/freezed_annotation.dart';

part 'weather.freezed.dart';
part 'weather.g.dart';

@freezed
abstract class WeatherResponse with _$WeatherResponse {
  const factory WeatherResponse({
    String? code,
    String? updateTime,
    String? fxLink,
    Now? now,
    Refer? refer,
  }) = _WeatherResponse;

  factory WeatherResponse.fromJson(Map<String, dynamic> json) =>
      _$WeatherResponseFromJson(json);
}

@freezed
abstract class Refer with _$Refer {
  const factory Refer({List<String>? sources, List<String>? license}) = _Refer;

  factory Refer.fromJson(Map<String, dynamic> json) => _$ReferFromJson(json);
}

@freezed
abstract class Now with _$Now {
  const factory Now({
    String? obsTime,
    String? temp,
    String? feelsLike,
    String? icon,
    String? text,
    String? wind360,
    String? windDir,
    String? windScale,
    String? windSpeed,
    String? humidity,
    String? precip,
    String? pressure,
    String? vis,
    String? cloud,
    String? dew,
  }) = _Now;

  factory Now.fromJson(Map<String, dynamic> json) => _$NowFromJson(json);
}
