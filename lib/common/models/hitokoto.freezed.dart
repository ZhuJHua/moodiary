// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'hitokoto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HitokotoResponse {

  int? get id;

  String? get uuid;

  String? get hitokoto;

  String? get type;

  String? get from;

  @JsonKey(name: 'from_who') String? get fromWho;

  String? get creator;

  @JsonKey(name: 'creator_uid') int? get creatorUid;

  int? get reviewer;

  @JsonKey(name: 'commit_from') String? get commitFrom;

  @JsonKey(name: 'created_at') String? get createdAt;

  int? get length;

  /// Create a copy of HitokotoResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HitokotoResponseCopyWith<HitokotoResponse> get copyWith =>
      _$HitokotoResponseCopyWithImpl<HitokotoResponse>(
          this as HitokotoResponse, _$identity);

  /// Serializes this HitokotoResponse to a JSON map.
  Map<String, dynamic> toJson();


  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is HitokotoResponse &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.uuid, uuid) || other.uuid == uuid) &&
            (identical(other.hitokoto, hitokoto) ||
                other.hitokoto == hitokoto) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.from, from) || other.from == from) &&
            (identical(other.fromWho, fromWho) || other.fromWho == fromWho) &&
            (identical(other.creator, creator) || other.creator == creator) &&
            (identical(other.creatorUid, creatorUid) ||
                other.creatorUid == creatorUid) &&
            (identical(other.reviewer, reviewer) ||
                other.reviewer == reviewer) &&
            (identical(other.commitFrom, commitFrom) ||
                other.commitFrom == commitFrom) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.length, length) || other.length == length));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(
          runtimeType,
          id,
          uuid,
          hitokoto,
          type,
          from,
          fromWho,
          creator,
          creatorUid,
          reviewer,
          commitFrom,
          createdAt,
          length);

  @override
  String toString() {
    return 'HitokotoResponse(id: $id, uuid: $uuid, hitokoto: $hitokoto, type: $type, from: $from, fromWho: $fromWho, creator: $creator, creatorUid: $creatorUid, reviewer: $reviewer, commitFrom: $commitFrom, createdAt: $createdAt, length: $length)';
  }


}

/// @nodoc
abstract mixin class $HitokotoResponseCopyWith<$Res> {
  factory $HitokotoResponseCopyWith(HitokotoResponse value,
      $Res Function(HitokotoResponse) _then) = _$HitokotoResponseCopyWithImpl;

  @useResult
  $Res call({
    int? id, String? uuid, String? hitokoto, String? type, String? from, @JsonKey(
        name: 'from_who') String? fromWho, String? creator, @JsonKey(
        name: 'creator_uid') int? creatorUid, int? reviewer, @JsonKey(
        name: 'commit_from') String? commitFrom, @JsonKey(
        name: 'created_at') String? createdAt, int? length
  });


}

/// @nodoc
class _$HitokotoResponseCopyWithImpl<$Res>
    implements $HitokotoResponseCopyWith<$Res> {
  _$HitokotoResponseCopyWithImpl(this._self, this._then);

  final HitokotoResponse _self;
  final $Res Function(HitokotoResponse) _then;

  /// Create a copy of HitokotoResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call(
      {Object? id = freezed, Object? uuid = freezed, Object? hitokoto = freezed, Object? type = freezed, Object? from = freezed, Object? fromWho = freezed, Object? creator = freezed, Object? creatorUid = freezed, Object? reviewer = freezed, Object? commitFrom = freezed, Object? createdAt = freezed, Object? length = freezed,}) {
    return _then(_self.copyWith(
      id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
      as int?,
      uuid: freezed == uuid
          ? _self.uuid
          : uuid // ignore: cast_nullable_to_non_nullable
      as String?,
      hitokoto: freezed == hitokoto
          ? _self.hitokoto
          : hitokoto // ignore: cast_nullable_to_non_nullable
      as String?,
      type: freezed == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
      as String?,
      from: freezed == from
          ? _self.from
          : from // ignore: cast_nullable_to_non_nullable
      as String?,
      fromWho: freezed == fromWho
          ? _self.fromWho
          : fromWho // ignore: cast_nullable_to_non_nullable
      as String?,
      creator: freezed == creator
          ? _self.creator
          : creator // ignore: cast_nullable_to_non_nullable
      as String?,
      creatorUid: freezed == creatorUid
          ? _self.creatorUid
          : creatorUid // ignore: cast_nullable_to_non_nullable
      as int?,
      reviewer: freezed == reviewer
          ? _self.reviewer
          : reviewer // ignore: cast_nullable_to_non_nullable
      as int?,
      commitFrom: freezed == commitFrom
          ? _self.commitFrom
          : commitFrom // ignore: cast_nullable_to_non_nullable
      as String?,
      createdAt: freezed == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
      as String?,
      length: freezed == length
          ? _self.length
          : length // ignore: cast_nullable_to_non_nullable
      as int?,
    ));
  }

}


/// @nodoc
@JsonSerializable()
class _HitokotoResponse implements HitokotoResponse {
  const _HitokotoResponse(
      {this.id, this.uuid, this.hitokoto, this.type, this.from, @JsonKey(
          name: 'from_who') this.fromWho, this.creator, @JsonKey(
          name: 'creator_uid') this.creatorUid, this.reviewer, @JsonKey(
          name: 'commit_from') this.commitFrom, @JsonKey(
          name: 'created_at') this.createdAt, this.length});

  factory _HitokotoResponse.fromJson(Map<String, dynamic> json) =>
      _$HitokotoResponseFromJson(json);

  @override final int? id;
  @override final String? uuid;
  @override final String? hitokoto;
  @override final String? type;
  @override final String? from;
  @override
  @JsonKey(name: 'from_who')
  final String? fromWho;
  @override final String? creator;
  @override
  @JsonKey(name: 'creator_uid')
  final int? creatorUid;
  @override final int? reviewer;
  @override
  @JsonKey(name: 'commit_from')
  final String? commitFrom;
  @override
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @override final int? length;

  /// Create a copy of HitokotoResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$HitokotoResponseCopyWith<_HitokotoResponse> get copyWith =>
      __$HitokotoResponseCopyWithImpl<_HitokotoResponse>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$HitokotoResponseToJson(this,);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _HitokotoResponse &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.uuid, uuid) || other.uuid == uuid) &&
            (identical(other.hitokoto, hitokoto) ||
                other.hitokoto == hitokoto) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.from, from) || other.from == from) &&
            (identical(other.fromWho, fromWho) || other.fromWho == fromWho) &&
            (identical(other.creator, creator) || other.creator == creator) &&
            (identical(other.creatorUid, creatorUid) ||
                other.creatorUid == creatorUid) &&
            (identical(other.reviewer, reviewer) ||
                other.reviewer == reviewer) &&
            (identical(other.commitFrom, commitFrom) ||
                other.commitFrom == commitFrom) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.length, length) || other.length == length));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(
          runtimeType,
          id,
          uuid,
          hitokoto,
          type,
          from,
          fromWho,
          creator,
          creatorUid,
          reviewer,
          commitFrom,
          createdAt,
          length);

  @override
  String toString() {
    return 'HitokotoResponse(id: $id, uuid: $uuid, hitokoto: $hitokoto, type: $type, from: $from, fromWho: $fromWho, creator: $creator, creatorUid: $creatorUid, reviewer: $reviewer, commitFrom: $commitFrom, createdAt: $createdAt, length: $length)';
  }


}

/// @nodoc
abstract mixin class _$HitokotoResponseCopyWith<$Res>
    implements $HitokotoResponseCopyWith<$Res> {
  factory _$HitokotoResponseCopyWith(_HitokotoResponse value,
      $Res Function(_HitokotoResponse) _then) = __$HitokotoResponseCopyWithImpl;

  @override
  @useResult
  $Res call({
    int? id, String? uuid, String? hitokoto, String? type, String? from, @JsonKey(
        name: 'from_who') String? fromWho, String? creator, @JsonKey(
        name: 'creator_uid') int? creatorUid, int? reviewer, @JsonKey(
        name: 'commit_from') String? commitFrom, @JsonKey(
        name: 'created_at') String? createdAt, int? length
  });


}

/// @nodoc
class __$HitokotoResponseCopyWithImpl<$Res>
    implements _$HitokotoResponseCopyWith<$Res> {
  __$HitokotoResponseCopyWithImpl(this._self, this._then);

  final _HitokotoResponse _self;
  final $Res Function(_HitokotoResponse) _then;

  /// Create a copy of HitokotoResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call(
      {Object? id = freezed, Object? uuid = freezed, Object? hitokoto = freezed, Object? type = freezed, Object? from = freezed, Object? fromWho = freezed, Object? creator = freezed, Object? creatorUid = freezed, Object? reviewer = freezed, Object? commitFrom = freezed, Object? createdAt = freezed, Object? length = freezed,}) {
    return _then(_HitokotoResponse(
      id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
      as int?,
      uuid: freezed == uuid
          ? _self.uuid
          : uuid // ignore: cast_nullable_to_non_nullable
      as String?,
      hitokoto: freezed == hitokoto
          ? _self.hitokoto
          : hitokoto // ignore: cast_nullable_to_non_nullable
      as String?,
      type: freezed == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
      as String?,
      from: freezed == from
          ? _self.from
          : from // ignore: cast_nullable_to_non_nullable
      as String?,
      fromWho: freezed == fromWho
          ? _self.fromWho
          : fromWho // ignore: cast_nullable_to_non_nullable
      as String?,
      creator: freezed == creator
          ? _self.creator
          : creator // ignore: cast_nullable_to_non_nullable
      as String?,
      creatorUid: freezed == creatorUid
          ? _self.creatorUid
          : creatorUid // ignore: cast_nullable_to_non_nullable
      as int?,
      reviewer: freezed == reviewer
          ? _self.reviewer
          : reviewer // ignore: cast_nullable_to_non_nullable
      as int?,
      commitFrom: freezed == commitFrom
          ? _self.commitFrom
          : commitFrom // ignore: cast_nullable_to_non_nullable
      as String?,
      createdAt: freezed == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
      as String?,
      length: freezed == length
          ? _self.length
          : length // ignore: cast_nullable_to_non_nullable
      as int?,
    ));
  }


}

// dart format on
