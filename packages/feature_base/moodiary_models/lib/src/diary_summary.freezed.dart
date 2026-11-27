// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'diary_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DiaryVisualMedia {

 String get name; bool get isVideo;
/// Create a copy of DiaryVisualMedia
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiaryVisualMediaCopyWith<DiaryVisualMedia> get copyWith => _$DiaryVisualMediaCopyWithImpl<DiaryVisualMedia>(this as DiaryVisualMedia, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as DiaryVisualMedia;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiaryVisualMedia&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.isVideo, _this.isVideo) || other.isVideo == _this.isVideo));
}


@override
int get hashCode {
  final _this = this as DiaryVisualMedia;
  return Object.hash(runtimeType,_this.name,_this.isVideo);
}

@override
String toString() {
  final _this = this as DiaryVisualMedia;
  return 'DiaryVisualMedia(name: ${_this.name}, isVideo: ${_this.isVideo})';
}


}

/// @nodoc
abstract mixin class $DiaryVisualMediaCopyWith<$Res>  {
  factory $DiaryVisualMediaCopyWith(DiaryVisualMedia value, $Res Function(DiaryVisualMedia) _then) = _$DiaryVisualMediaCopyWithImpl;
@useResult
$Res call({
 String name, bool isVideo
});




}
/// @nodoc
class _$DiaryVisualMediaCopyWithImpl<$Res>
    implements $DiaryVisualMediaCopyWith<$Res> {
  _$DiaryVisualMediaCopyWithImpl(this._self, this._then);

  final DiaryVisualMedia _self;
  final $Res Function(DiaryVisualMedia) _then;

/// Create a copy of DiaryVisualMedia
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? isVideo = null,}) {
  return _then(DiaryVisualMedia(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,isVideo: null == isVideo ? _self.isVideo : isVideo // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [DiaryVisualMedia].
extension DiaryVisualMediaPatterns on DiaryVisualMedia {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DiaryVisualMedia value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DiaryVisualMedia() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DiaryVisualMedia value)  $default,){
final _that = this;
switch (_that) {
case _DiaryVisualMedia():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DiaryVisualMedia value)?  $default,){
final _that = this;
switch (_that) {
case _DiaryVisualMedia() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  bool isVideo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DiaryVisualMedia() when $default != null:
return $default(_that.name,_that.isVideo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  bool isVideo)  $default,) {final _that = this;
switch (_that) {
case _DiaryVisualMedia():
return $default(_that.name,_that.isVideo);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  bool isVideo)?  $default,) {final _that = this;
switch (_that) {
case _DiaryVisualMedia() when $default != null:
return $default(_that.name,_that.isVideo);case _:
  return null;

}
}

}

/// @nodoc


class _DiaryVisualMedia implements DiaryVisualMedia {
  const _DiaryVisualMedia({required this.name, required this.isVideo});
  

@override final  String name;
@override final  bool isVideo;

/// Create a copy of DiaryVisualMedia
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DiaryVisualMediaCopyWith<_DiaryVisualMedia> get copyWith => __$DiaryVisualMediaCopyWithImpl<_DiaryVisualMedia>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DiaryVisualMedia&&(identical(other.name, name) || other.name == name)&&(identical(other.isVideo, isVideo) || other.isVideo == isVideo));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,isVideo);
}

@override
String toString() {
    return 'DiaryVisualMedia(name: $name, isVideo: $isVideo)';
}


}

/// @nodoc
abstract mixin class _$DiaryVisualMediaCopyWith<$Res> implements $DiaryVisualMediaCopyWith<$Res> {
  factory _$DiaryVisualMediaCopyWith(_DiaryVisualMedia value, $Res Function(_DiaryVisualMedia) _then) = __$DiaryVisualMediaCopyWithImpl;
@override @useResult
$Res call({
 String name, bool isVideo
});




}
/// @nodoc
class __$DiaryVisualMediaCopyWithImpl<$Res>
    implements _$DiaryVisualMediaCopyWith<$Res> {
  __$DiaryVisualMediaCopyWithImpl(this._self, this._then);

  final _DiaryVisualMedia _self;
  final $Res Function(_DiaryVisualMedia) _then;

/// Create a copy of DiaryVisualMedia
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? isVideo = null,}) {
  return _then(_DiaryVisualMedia(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,isVideo: null == isVideo ? _self.isVideo : isVideo // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$DiarySummary {


/// Create a copy of DiarySummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiarySummaryCopyWith<DiarySummary> get copyWith => _$DiarySummaryCopyWithImpl<DiarySummary>(this as DiarySummary, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as DiarySummary;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiarySummary&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.contentPreview, _this.contentPreview) || other.contentPreview == _this.contentPreview)&&(identical(other.time, _this.time) || other.time == _this.time)&&(identical(other.lastModified, _this.lastModified) || other.lastModified == _this.lastModified)&&(identical(other.mood, _this.mood) || other.mood == _this.mood)&&(identical(other.weatherIcon, _this.weatherIcon) || other.weatherIcon == _this.weatherIcon)&&(identical(other.weatherTemp, _this.weatherTemp) || other.weatherTemp == _this.weatherTemp)&&(identical(other.placeId, _this.placeId) || other.placeId == _this.placeId)&&(identical(other.aspect, _this.aspect) || other.aspect == _this.aspect)&&const DeepCollectionEquality().equals(other.visualMedia, _this.visualMedia)&&(identical(other.moreVisualCount, _this.moreVisualCount) || other.moreVisualCount == _this.moreVisualCount)&&(identical(other.audioCount, _this.audioCount) || other.audioCount == _this.audioCount)&&(identical(other.fileCount, _this.fileCount) || other.fileCount == _this.fileCount));
}


@override
int get hashCode {
  final _this = this as DiarySummary;
  return Object.hash(runtimeType,_this.id,_this.title,_this.contentPreview,_this.time,_this.lastModified,_this.mood,_this.weatherIcon,_this.weatherTemp,_this.placeId,_this.aspect,const DeepCollectionEquality().hash(_this.visualMedia),_this.moreVisualCount,_this.audioCount,_this.fileCount);
}

@override
String toString() {
  final _this = this as DiarySummary;
  return 'DiarySummary(id: ${_this.id}, title: ${_this.title}, contentPreview: ${_this.contentPreview}, time: ${_this.time}, lastModified: ${_this.lastModified}, mood: ${_this.mood}, weatherIcon: ${_this.weatherIcon}, weatherTemp: ${_this.weatherTemp}, placeId: ${_this.placeId}, aspect: ${_this.aspect}, visualMedia: ${_this.visualMedia}, moreVisualCount: ${_this.moreVisualCount}, audioCount: ${_this.audioCount}, fileCount: ${_this.fileCount})';
}


}

/// @nodoc
abstract mixin class $DiarySummaryCopyWith<$Res>  {
  factory $DiarySummaryCopyWith(DiarySummary value, $Res Function(DiarySummary) _then) = _$DiarySummaryCopyWithImpl;
@useResult
$Res call({
 String id, String title, String contentPreview, DateTime time, DateTime lastModified, DiaryMood? mood, String? weatherIcon, String? weatherTemp, String? placeId, double? aspect, List<DiaryVisualMedia> visualMedia, int moreVisualCount, int audioCount, int fileCount
});




}
/// @nodoc
class _$DiarySummaryCopyWithImpl<$Res>
    implements $DiarySummaryCopyWith<$Res> {
  _$DiarySummaryCopyWithImpl(this._self, this._then);

  final DiarySummary _self;
  final $Res Function(DiarySummary) _then;

/// Create a copy of DiarySummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? contentPreview = null,Object? time = null,Object? lastModified = null,Object? mood = freezed,Object? weatherIcon = freezed,Object? weatherTemp = freezed,Object? placeId = freezed,Object? aspect = freezed,Object? visualMedia = null,Object? moreVisualCount = null,Object? audioCount = null,Object? fileCount = null,}) {
  return _then(DiarySummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,contentPreview: null == contentPreview ? _self.contentPreview : contentPreview // ignore: cast_nullable_to_non_nullable
as String,time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as DateTime,lastModified: null == lastModified ? _self.lastModified : lastModified // ignore: cast_nullable_to_non_nullable
as DateTime,mood: freezed == mood ? _self.mood : mood // ignore: cast_nullable_to_non_nullable
as DiaryMood?,weatherIcon: freezed == weatherIcon ? _self.weatherIcon : weatherIcon // ignore: cast_nullable_to_non_nullable
as String?,weatherTemp: freezed == weatherTemp ? _self.weatherTemp : weatherTemp // ignore: cast_nullable_to_non_nullable
as String?,placeId: freezed == placeId ? _self.placeId : placeId // ignore: cast_nullable_to_non_nullable
as String?,aspect: freezed == aspect ? _self.aspect : aspect // ignore: cast_nullable_to_non_nullable
as double?,visualMedia: null == visualMedia ? _self.visualMedia : visualMedia // ignore: cast_nullable_to_non_nullable
as List<DiaryVisualMedia>,moreVisualCount: null == moreVisualCount ? _self.moreVisualCount : moreVisualCount // ignore: cast_nullable_to_non_nullable
as int,audioCount: null == audioCount ? _self.audioCount : audioCount // ignore: cast_nullable_to_non_nullable
as int,fileCount: null == fileCount ? _self.fileCount : fileCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [DiarySummary].
extension DiarySummaryPatterns on DiarySummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({required TResult orElse(),}){
final _that = this;
switch (_that) {
case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(){
final _that = this;
switch (_that) {
case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(){
final _that = this;
switch (_that) {
case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({required TResult orElse(),}) {final _that = this;
switch (_that) {
case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>() {final _that = this;
switch (_that) {
case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>() {final _that = this;
switch (_that) {
case _:
  return null;

}
}

}

// dart format on
