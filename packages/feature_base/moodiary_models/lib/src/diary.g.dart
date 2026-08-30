// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Diary _$DiaryFromJson(Map<String, dynamic> json) => _Diary(
  id: json['id'] as String,
  categoryId: json['categoryId'] as String?,
  title: json['title'] as String,
  content: json['content'] as String,
  contentText: json['contentText'] as String,
  time: const UtcDateTimeConverter().fromJson(json['time'] as String),
  lastModified: const UtcDateTimeConverter().fromJson(
    json['lastModified'] as String,
  ),
  show: json['show'] as bool,
  mood: $enumDecode(_$DiaryMoodEnumMap, json['mood']),
  weather: json['weather'] == null
      ? null
      : DiaryWeather.fromJson(json['weather'] as Map<String, dynamic>),
  imageName: (json['imageName'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  audioName: (json['audioName'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  videoName: (json['videoName'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
  position: json['position'] == null
      ? null
      : DiaryPosition.fromJson(json['position'] as Map<String, dynamic>),
  type: json['type'] as String,
  aspect: (json['aspect'] as num?)?.toDouble(),
);

Map<String, dynamic> _$DiaryToJson(_Diary instance) => <String, dynamic>{
  'id': instance.id,
  'categoryId': instance.categoryId,
  'title': instance.title,
  'content': instance.content,
  'contentText': instance.contentText,
  'time': const UtcDateTimeConverter().toJson(instance.time),
  'lastModified': const UtcDateTimeConverter().toJson(instance.lastModified),
  'show': instance.show,
  'mood': _$DiaryMoodEnumMap[instance.mood]!,
  'weather': instance.weather,
  'imageName': instance.imageName,
  'audioName': instance.audioName,
  'videoName': instance.videoName,
  'tags': instance.tags,
  'position': instance.position,
  'type': instance.type,
  'aspect': instance.aspect,
};

const _$DiaryMoodEnumMap = {
  DiaryMood.negative: 'negative',
  DiaryMood.neutral: 'neutral',
  DiaryMood.positive: 'positive',
};
