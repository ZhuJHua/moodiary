// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'media_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MediaInfo {

 String get fileName; String? get name; int? get durationMs;@UtcDateTimeConverter() DateTime get lastModified;
/// Create a copy of MediaInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MediaInfoCopyWith<MediaInfo> get copyWith => _$MediaInfoCopyWithImpl<MediaInfo>(this as MediaInfo, _$identity);

  /// Serializes this MediaInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MediaInfo&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.name, name) || other.name == name)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.lastModified, lastModified) || other.lastModified == lastModified));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fileName,name,durationMs,lastModified);

@override
String toString() {
  return 'MediaInfo(fileName: $fileName, name: $name, durationMs: $durationMs, lastModified: $lastModified)';
}


}

/// @nodoc
abstract mixin class $MediaInfoCopyWith<$Res>  {
  factory $MediaInfoCopyWith(MediaInfo value, $Res Function(MediaInfo) _then) = _$MediaInfoCopyWithImpl;
@useResult
$Res call({
 String fileName, String? name, int? durationMs,@UtcDateTimeConverter() DateTime lastModified
});




}
/// @nodoc
class _$MediaInfoCopyWithImpl<$Res>
    implements $MediaInfoCopyWith<$Res> {
  _$MediaInfoCopyWithImpl(this._self, this._then);

  final MediaInfo _self;
  final $Res Function(MediaInfo) _then;

/// Create a copy of MediaInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fileName = null,Object? name = freezed,Object? durationMs = freezed,Object? lastModified = null,}) {
  return _then(MediaInfo(
fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,durationMs: freezed == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int?,lastModified: null == lastModified ? _self.lastModified : lastModified // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [MediaInfo].
extension MediaInfoPatterns on MediaInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MediaInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MediaInfo() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MediaInfo value)  $default,){
final _that = this;
switch (_that) {
case _MediaInfo():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MediaInfo value)?  $default,){
final _that = this;
switch (_that) {
case _MediaInfo() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String fileName,  String? name,  int? durationMs, @UtcDateTimeConverter()  DateTime lastModified)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MediaInfo() when $default != null:
return $default(_that.fileName,_that.name,_that.durationMs,_that.lastModified);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String fileName,  String? name,  int? durationMs, @UtcDateTimeConverter()  DateTime lastModified)  $default,) {final _that = this;
switch (_that) {
case _MediaInfo():
return $default(_that.fileName,_that.name,_that.durationMs,_that.lastModified);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String fileName,  String? name,  int? durationMs, @UtcDateTimeConverter()  DateTime lastModified)?  $default,) {final _that = this;
switch (_that) {
case _MediaInfo() when $default != null:
return $default(_that.fileName,_that.name,_that.durationMs,_that.lastModified);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MediaInfo extends MediaInfo {
  const _MediaInfo({required this.fileName, this.name, this.durationMs, @UtcDateTimeConverter() required this.lastModified}): super._();
  factory _MediaInfo.fromJson(Map<String, dynamic> json) => _$MediaInfoFromJson(json);

@override final  String fileName;
@override final  String? name;
@override final  int? durationMs;
@override@UtcDateTimeConverter() final  DateTime lastModified;

/// Create a copy of MediaInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MediaInfoCopyWith<_MediaInfo> get copyWith => __$MediaInfoCopyWithImpl<_MediaInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MediaInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MediaInfo&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.name, name) || other.name == name)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.lastModified, lastModified) || other.lastModified == lastModified));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fileName,name,durationMs,lastModified);

@override
String toString() {
  return 'MediaInfo(fileName: $fileName, name: $name, durationMs: $durationMs, lastModified: $lastModified)';
}


}

/// @nodoc
abstract mixin class _$MediaInfoCopyWith<$Res> implements $MediaInfoCopyWith<$Res> {
  factory _$MediaInfoCopyWith(_MediaInfo value, $Res Function(_MediaInfo) _then) = __$MediaInfoCopyWithImpl;
@override @useResult
$Res call({
 String fileName, String? name, int? durationMs,@UtcDateTimeConverter() DateTime lastModified
});




}
/// @nodoc
class __$MediaInfoCopyWithImpl<$Res>
    implements _$MediaInfoCopyWith<$Res> {
  __$MediaInfoCopyWithImpl(this._self, this._then);

  final _MediaInfo _self;
  final $Res Function(_MediaInfo) _then;

/// Create a copy of MediaInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fileName = null,Object? name = freezed,Object? durationMs = freezed,Object? lastModified = null,}) {
  return _then(_MediaInfo(
fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,durationMs: freezed == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int?,lastModified: null == lastModified ? _self.lastModified : lastModified // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
