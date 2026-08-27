// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_meta.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DiaryPosition _$DiaryPositionFromJson(Map<String, dynamic> json) =>
    _DiaryPosition(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      name: json['name'] as String,
    );

Map<String, dynamic> _$DiaryPositionToJson(_DiaryPosition instance) =>
    <String, dynamic>{
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'name': instance.name,
    };

_DiaryWeather _$DiaryWeatherFromJson(Map<String, dynamic> json) =>
    _DiaryWeather(
      icon: json['icon'] as String,
      temp: json['temp'] as String,
      text: json['text'] as String,
    );

Map<String, dynamic> _$DiaryWeatherToJson(_DiaryWeather instance) =>
    <String, dynamic>{
      'icon': instance.icon,
      'temp': instance.temp,
      'text': instance.text,
    };
