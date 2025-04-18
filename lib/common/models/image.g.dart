// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BingImage _$BingImageFromJson(Map<String, dynamic> json) => _BingImage(
  images:
      (json['images'] as List<dynamic>?)
          ?.map((e) => Images.fromJson(e as Map<String, dynamic>))
          .toList(),
  tooltips:
      json['tooltips'] == null
          ? null
          : Tooltips.fromJson(json['tooltips'] as Map<String, dynamic>),
);

Map<String, dynamic> _$BingImageToJson(_BingImage instance) =>
    <String, dynamic>{
      if (instance.images case final value?) 'images': value,
      if (instance.tooltips case final value?) 'tooltips': value,
    };

_Tooltips _$TooltipsFromJson(Map<String, dynamic> json) => _Tooltips(
  loading: json['loading'] as String?,
  previous: json['previous'] as String?,
  next: json['next'] as String?,
  walle: json['walle'] as String?,
  walls: json['walls'] as String?,
);

Map<String, dynamic> _$TooltipsToJson(_Tooltips instance) => <String, dynamic>{
  if (instance.loading case final value?) 'loading': value,
  if (instance.previous case final value?) 'previous': value,
  if (instance.next case final value?) 'next': value,
  if (instance.walle case final value?) 'walle': value,
  if (instance.walls case final value?) 'walls': value,
};

_Images _$ImagesFromJson(Map<String, dynamic> json) => _Images(
  startdate: json['startdate'] as String?,
  fullstartdate: json['fullstartdate'] as String?,
  enddate: json['enddate'] as String?,
  url: json['url'] as String?,
  urlbase: json['urlbase'] as String?,
  copyright: json['copyright'] as String?,
  copyrightlink: json['copyrightlink'] as String?,
  title: json['title'] as String?,
  quiz: json['quiz'] as String?,
  wp: json['wp'] as bool?,
  hsh: json['hsh'] as String?,
  drk: (json['drk'] as num?)?.toInt(),
  top: (json['top'] as num?)?.toInt(),
  bot: (json['bot'] as num?)?.toInt(),
  hs: json['hs'] as List<dynamic>?,
);

Map<String, dynamic> _$ImagesToJson(_Images instance) => <String, dynamic>{
  if (instance.startdate case final value?) 'startdate': value,
  if (instance.fullstartdate case final value?) 'fullstartdate': value,
  if (instance.enddate case final value?) 'enddate': value,
  if (instance.url case final value?) 'url': value,
  if (instance.urlbase case final value?) 'urlbase': value,
  if (instance.copyright case final value?) 'copyright': value,
  if (instance.copyrightlink case final value?) 'copyrightlink': value,
  if (instance.title case final value?) 'title': value,
  if (instance.quiz case final value?) 'quiz': value,
  if (instance.wp case final value?) 'wp': value,
  if (instance.hsh case final value?) 'hsh': value,
  if (instance.drk case final value?) 'drk': value,
  if (instance.top case final value?) 'top': value,
  if (instance.bot case final value?) 'bot': value,
  if (instance.hs case final value?) 'hs': value,
};
