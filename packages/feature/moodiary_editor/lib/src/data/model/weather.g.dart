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
      now: json['now'] == null
          ? null
          : Now.fromJson(json['now'] as Map<String, dynamic>),
      refer: json['refer'] == null
          ? null
          : Refer.fromJson(json['refer'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$WeatherResponseToJson(_WeatherResponse instance) =>
    <String, dynamic>{
      'code': ?instance.code,
      'updateTime': ?instance.updateTime,
      'fxLink': ?instance.fxLink,
      'now': ?instance.now,
      'refer': ?instance.refer,
    };

_Refer _$ReferFromJson(Map<String, dynamic> json) => _Refer(
  sources: (json['sources'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  license: (json['license'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$ReferToJson(_Refer instance) => <String, dynamic>{
  'sources': ?instance.sources,
  'license': ?instance.license,
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
  'obsTime': ?instance.obsTime,
  'temp': ?instance.temp,
  'feelsLike': ?instance.feelsLike,
  'icon': ?instance.icon,
  'text': ?instance.text,
  'wind360': ?instance.wind360,
  'windDir': ?instance.windDir,
  'windScale': ?instance.windScale,
  'windSpeed': ?instance.windSpeed,
  'humidity': ?instance.humidity,
  'precip': ?instance.precip,
  'pressure': ?instance.pressure,
  'vis': ?instance.vis,
  'cloud': ?instance.cloud,
  'dew': ?instance.dew,
};
