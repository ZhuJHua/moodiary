// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'geo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GeoResponse _$GeoResponseFromJson(Map<String, dynamic> json) => _GeoResponse(
  code: json['code'] as String?,
  location:
      (json['location'] as List<dynamic>?)
          ?.map((e) => Location.fromJson(e as Map<String, dynamic>))
          .toList(),
  refer:
      json['refer'] == null
          ? null
          : Refer.fromJson(json['refer'] as Map<String, dynamic>),
);

Map<String, dynamic> _$GeoResponseToJson(_GeoResponse instance) =>
    <String, dynamic>{
      if (instance.code case final value?) 'code': value,
      if (instance.location case final value?) 'location': value,
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

_Location _$LocationFromJson(Map<String, dynamic> json) => _Location(
  name: json['name'] as String?,
  id: json['id'] as String?,
  lat: json['lat'] as String?,
  lon: json['lon'] as String?,
  adm2: json['adm2'] as String?,
  adm1: json['adm1'] as String?,
  country: json['country'] as String?,
  tz: json['tz'] as String?,
  utcOffset: json['utcOffset'] as String?,
  isDst: json['isDst'] as String?,
  type: json['type'] as String?,
  rank: json['rank'] as String?,
  fxLink: json['fxLink'] as String?,
);

Map<String, dynamic> _$LocationToJson(_Location instance) => <String, dynamic>{
  if (instance.name case final value?) 'name': value,
  if (instance.id case final value?) 'id': value,
  if (instance.lat case final value?) 'lat': value,
  if (instance.lon case final value?) 'lon': value,
  if (instance.adm2 case final value?) 'adm2': value,
  if (instance.adm1 case final value?) 'adm1': value,
  if (instance.country case final value?) 'country': value,
  if (instance.tz case final value?) 'tz': value,
  if (instance.utcOffset case final value?) 'utcOffset': value,
  if (instance.isDst case final value?) 'isDst': value,
  if (instance.type case final value?) 'type': value,
  if (instance.rank case final value?) 'rank': value,
  if (instance.fxLink case final value?) 'fxLink': value,
};
