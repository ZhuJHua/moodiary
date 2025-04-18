// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weather.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WeatherResponse _$WeatherResponseFromJson(Map<String, dynamic> json) =>
    _WeatherResponse(
      code: json['code'] as String?,
      updateTime: json['updateTime'] as String?,
      fxLink: json['fxLink'] as String?,
      now:
          json['now'] == null
              ? null
              : Now.fromJson(json['now'] as Map<String, dynamic>),
      refer:
          json['refer'] == null
              ? null
              : Refer.fromJson(json['refer'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$WeatherResponseToJson(_WeatherResponse instance) =>
    <String, dynamic>{
      if (instance.code case final value?) 'code': value,
      if (instance.updateTime case final value?) 'updateTime': value,
      if (instance.fxLink case final value?) 'fxLink': value,
      if (instance.now case final value?) 'now': value,
      if (instance.refer case final value?) 'refer': value,
    };

_Refer _$ReferFromJson(Map<String, dynamic> json) => _Refer(
  sources:
      (json['sources'] as List<dynamic>?)?.map((e) => e as String).toList(),
  license:
      (json['license'] as List<dynamic>?)?.map((e) => e as String).toList(),
);

Map<String, dynamic> _$ReferToJson(_Refer instance) => <String, dynamic>{
  if (instance.sources case final value?) 'sources': value,
  if (instance.license case final value?) 'license': value,
};

_Now _$NowFromJson(Map<String, dynamic> json) => _Now(
  obsTime: json['obsTime'] as String?,
  temp: json['temp'] as String?,
  feelsLike: json['feelsLike'] as String?,
  icon: json['icon'] as String?,
  text: json['text'] as String?,
  wind360: json['wind360'] as String?,
  windDir: json['windDir'] as String?,
  windScale: json['windScale'] as String?,
  windSpeed: json['windSpeed'] as String?,
  humidity: json['humidity'] as String?,
  precip: json['precip'] as String?,
  pressure: json['pressure'] as String?,
  vis: json['vis'] as String?,
  cloud: json['cloud'] as String?,
  dew: json['dew'] as String?,
);

Map<String, dynamic> _$NowToJson(_Now instance) => <String, dynamic>{
  if (instance.obsTime case final value?) 'obsTime': value,
  if (instance.temp case final value?) 'temp': value,
  if (instance.feelsLike case final value?) 'feelsLike': value,
  if (instance.icon case final value?) 'icon': value,
  if (instance.text case final value?) 'text': value,
  if (instance.wind360 case final value?) 'wind360': value,
  if (instance.windDir case final value?) 'windDir': value,
  if (instance.windScale case final value?) 'windScale': value,
  if (instance.windSpeed case final value?) 'windSpeed': value,
  if (instance.humidity case final value?) 'humidity': value,
  if (instance.precip case final value?) 'precip': value,
  if (instance.pressure case final value?) 'pressure': value,
  if (instance.vis case final value?) 'vis': value,
  if (instance.cloud case final value?) 'cloud': value,
  if (instance.dew case final value?) 'dew': value,
};
