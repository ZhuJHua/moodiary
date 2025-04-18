// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hitokoto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HitokotoResponse _$HitokotoResponseFromJson(Map<String, dynamic> json) =>
    _HitokotoResponse(
      id: (json['id'] as num?)?.toInt(),
      uuid: json['uuid'] as String?,
      hitokoto: json['hitokoto'] as String?,
      type: json['type'] as String?,
      from: json['from'] as String?,
      fromWho: json['from_who'] as String?,
      creator: json['creator'] as String?,
      creatorUid: (json['creator_uid'] as num?)?.toInt(),
      reviewer: (json['reviewer'] as num?)?.toInt(),
      commitFrom: json['commit_from'] as String?,
      createdAt: json['created_at'] as String?,
      length: (json['length'] as num?)?.toInt(),
    );

Map<String, dynamic> _$HitokotoResponseToJson(_HitokotoResponse instance) =>
    <String, dynamic>{
      if (instance.id case final value?) 'id': value,
      if (instance.uuid case final value?) 'uuid': value,
      if (instance.hitokoto case final value?) 'hitokoto': value,
      if (instance.type case final value?) 'type': value,
      if (instance.from case final value?) 'from': value,
      if (instance.fromWho case final value?) 'from_who': value,
      if (instance.creator case final value?) 'creator': value,
      if (instance.creatorUid case final value?) 'creator_uid': value,
      if (instance.reviewer case final value?) 'reviewer': value,
      if (instance.commitFrom case final value?) 'commit_from': value,
      if (instance.createdAt case final value?) 'created_at': value,
      if (instance.length case final value?) 'length': value,
    };
