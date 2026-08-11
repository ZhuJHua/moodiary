// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'media_info_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MediaInfoEvent {

 bool get fromSync;
/// Create a copy of MediaInfoEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MediaInfoEventCopyWith<MediaInfoEvent> get copyWith => _$MediaInfoEventCopyWithImpl<MediaInfoEvent>(this as MediaInfoEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MediaInfoEvent&&(identical(other.fromSync, fromSync) || other.fromSync == fromSync));
}


@override
int get hashCode => Object.hash(runtimeType,fromSync);

@override
String toString() {
  return 'MediaInfoEvent(fromSync: $fromSync)';
}


}

/// @nodoc
abstract mixin class $MediaInfoEventCopyWith<$Res>  {
  factory $MediaInfoEventCopyWith(MediaInfoEvent value, $Res Function(MediaInfoEvent) _then) = _$MediaInfoEventCopyWithImpl;
@useResult
$Res call({
 bool fromSync
});




}
/// @nodoc
class _$MediaInfoEventCopyWithImpl<$Res>
    implements $MediaInfoEventCopyWith<$Res> {
  _$MediaInfoEventCopyWithImpl(this._self, this._then);

  final MediaInfoEvent _self;
  final $Res Function(MediaInfoEvent) _then;

/// Create a copy of MediaInfoEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fromSync = null,}) {
  return _then(_self.copyWith(
fromSync: null == fromSync ? _self.fromSync : fromSync // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [MediaInfoEvent].
extension MediaInfoEventPatterns on MediaInfoEvent {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( MediaInfoUpserted value)?  upserted,TResult Function( MediaInfoDeleted value)?  deleted,required TResult orElse(),}){
final _that = this;
switch (_that) {
case MediaInfoUpserted() when upserted != null:
return upserted(_that);case MediaInfoDeleted() when deleted != null:
return deleted(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( MediaInfoUpserted value)  upserted,required TResult Function( MediaInfoDeleted value)  deleted,}){
final _that = this;
switch (_that) {
case MediaInfoUpserted():
return upserted(_that);case MediaInfoDeleted():
return deleted(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( MediaInfoUpserted value)?  upserted,TResult? Function( MediaInfoDeleted value)?  deleted,}){
final _that = this;
switch (_that) {
case MediaInfoUpserted() when upserted != null:
return upserted(_that);case MediaInfoDeleted() when deleted != null:
return deleted(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( MediaInfo mediaInfo,  bool fromSync)?  upserted,TResult Function( String fileName,  bool fromSync)?  deleted,required TResult orElse(),}) {final _that = this;
switch (_that) {
case MediaInfoUpserted() when upserted != null:
return upserted(_that.mediaInfo,_that.fromSync);case MediaInfoDeleted() when deleted != null:
return deleted(_that.fileName,_that.fromSync);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( MediaInfo mediaInfo,  bool fromSync)  upserted,required TResult Function( String fileName,  bool fromSync)  deleted,}) {final _that = this;
switch (_that) {
case MediaInfoUpserted():
return upserted(_that.mediaInfo,_that.fromSync);case MediaInfoDeleted():
return deleted(_that.fileName,_that.fromSync);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( MediaInfo mediaInfo,  bool fromSync)?  upserted,TResult? Function( String fileName,  bool fromSync)?  deleted,}) {final _that = this;
switch (_that) {
case MediaInfoUpserted() when upserted != null:
return upserted(_that.mediaInfo,_that.fromSync);case MediaInfoDeleted() when deleted != null:
return deleted(_that.fileName,_that.fromSync);case _:
  return null;

}
}

}

/// @nodoc


class MediaInfoUpserted implements MediaInfoEvent {
  const MediaInfoUpserted(this.mediaInfo, {this.fromSync = false});
  

 final  MediaInfo mediaInfo;
@override@JsonKey() final  bool fromSync;

/// Create a copy of MediaInfoEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MediaInfoUpsertedCopyWith<MediaInfoUpserted> get copyWith => _$MediaInfoUpsertedCopyWithImpl<MediaInfoUpserted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MediaInfoUpserted&&(identical(other.mediaInfo, mediaInfo) || other.mediaInfo == mediaInfo)&&(identical(other.fromSync, fromSync) || other.fromSync == fromSync));
}


@override
int get hashCode => Object.hash(runtimeType,mediaInfo,fromSync);

@override
String toString() {
  return 'MediaInfoEvent.upserted(mediaInfo: $mediaInfo, fromSync: $fromSync)';
}


}

/// @nodoc
abstract mixin class $MediaInfoUpsertedCopyWith<$Res> implements $MediaInfoEventCopyWith<$Res> {
  factory $MediaInfoUpsertedCopyWith(MediaInfoUpserted value, $Res Function(MediaInfoUpserted) _then) = _$MediaInfoUpsertedCopyWithImpl;
@override @useResult
$Res call({
 MediaInfo mediaInfo, bool fromSync
});


$MediaInfoCopyWith<$Res> get mediaInfo;

}
/// @nodoc
class _$MediaInfoUpsertedCopyWithImpl<$Res>
    implements $MediaInfoUpsertedCopyWith<$Res> {
  _$MediaInfoUpsertedCopyWithImpl(this._self, this._then);

  final MediaInfoUpserted _self;
  final $Res Function(MediaInfoUpserted) _then;

/// Create a copy of MediaInfoEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mediaInfo = null,Object? fromSync = null,}) {
  return _then(MediaInfoUpserted(
null == mediaInfo ? _self.mediaInfo : mediaInfo // ignore: cast_nullable_to_non_nullable
as MediaInfo,fromSync: null == fromSync ? _self.fromSync : fromSync // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of MediaInfoEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaInfoCopyWith<$Res> get mediaInfo {
  
  return $MediaInfoCopyWith<$Res>(_self.mediaInfo, (value) {
    return _then(_self.copyWith(mediaInfo: value));
  });
}
}

/// @nodoc


class MediaInfoDeleted implements MediaInfoEvent {
  const MediaInfoDeleted(this.fileName, {this.fromSync = false});
  

 final  String fileName;
@override@JsonKey() final  bool fromSync;

/// Create a copy of MediaInfoEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MediaInfoDeletedCopyWith<MediaInfoDeleted> get copyWith => _$MediaInfoDeletedCopyWithImpl<MediaInfoDeleted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MediaInfoDeleted&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.fromSync, fromSync) || other.fromSync == fromSync));
}


@override
int get hashCode => Object.hash(runtimeType,fileName,fromSync);

@override
String toString() {
  return 'MediaInfoEvent.deleted(fileName: $fileName, fromSync: $fromSync)';
}


}

/// @nodoc
abstract mixin class $MediaInfoDeletedCopyWith<$Res> implements $MediaInfoEventCopyWith<$Res> {
  factory $MediaInfoDeletedCopyWith(MediaInfoDeleted value, $Res Function(MediaInfoDeleted) _then) = _$MediaInfoDeletedCopyWithImpl;
@override @useResult
$Res call({
 String fileName, bool fromSync
});




}
/// @nodoc
class _$MediaInfoDeletedCopyWithImpl<$Res>
    implements $MediaInfoDeletedCopyWith<$Res> {
  _$MediaInfoDeletedCopyWithImpl(this._self, this._then);

  final MediaInfoDeleted _self;
  final $Res Function(MediaInfoDeleted) _then;

/// Create a copy of MediaInfoEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fileName = null,Object? fromSync = null,}) {
  return _then(MediaInfoDeleted(
null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,fromSync: null == fromSync ? _self.fromSync : fromSync // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
