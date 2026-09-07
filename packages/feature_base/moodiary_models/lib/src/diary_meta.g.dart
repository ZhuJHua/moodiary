// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_meta.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DiaryWeather _$DiaryWeatherFromJson(Map<String, dynamic> json) =>
    _DiaryWeather(
      icon: json['icon'] as String,
      temp: json['temp'] as String?,
      text: json['text'] as String,
    );

Map<String, dynamic> _$DiaryWeatherToJson(_DiaryWeather instance) =>
    <String, dynamic>{
      'icon': instance.icon,
      'temp': instance.temp,
      'text': instance.text,
    };
