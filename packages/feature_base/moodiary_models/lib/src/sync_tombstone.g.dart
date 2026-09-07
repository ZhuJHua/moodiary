// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_tombstone.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SyncTombstone _$SyncTombstoneFromJson(Map<String, dynamic> json) =>
    _SyncTombstone(
      key: json['key'] as String,
      timeMs: (json['timeMs'] as num).toInt(),
      pushedBackends: (json['pushedBackends'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$SyncTombstoneToJson(_SyncTombstone instance) =>
    <String, dynamic>{
      'key': instance.key,
      'timeMs': instance.timeMs,
      'pushedBackends': instance.pushedBackends,
    };
