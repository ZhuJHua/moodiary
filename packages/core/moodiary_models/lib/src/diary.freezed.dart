// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'diary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Diary {

 String get id;@Index() String? get categoryId; String get title; String get content; String get contentText;@Index()@UtcDateTimeConverter() DateTime get time;@UtcDateTimeConverter() DateTime get lastModified;@Index() bool get show;@Index() bool get deleted; double get mood; List<String> get weather; List<String> get imageName; List<String> get audioName; List<String> get videoName; List<String> get tags; List<String> get position; String get type; int? get imageColor; double? get aspect;
/// Create a copy of Diary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiaryCopyWith<Diary> get copyWith => _$DiaryCopyWithImpl<Diary>(this as Diary, _$identity);

  /// Serializes this Diary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Diary&&(identical(other.id, id) || other.id == id)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.title, title) || other.title == title)&&(identical(other.content, content) || other.content == content)&&(identical(other.contentText, contentText) || other.contentText == contentText)&&(identical(other.time, time) || other.time == time)&&(identical(other.lastModified, lastModified) || other.lastModified == lastModified)&&(identical(other.show, show) || other.show == show)&&(identical(other.deleted, deleted) || other.deleted == deleted)&&(identical(other.mood, mood) || other.mood == mood)&&const DeepCollectionEquality().equals(other.weather, weather)&&const DeepCollectionEquality().equals(other.imageName, imageName)&&const DeepCollectionEquality().equals(other.audioName, audioName)&&const DeepCollectionEquality().equals(other.videoName, videoName)&&const DeepCollectionEquality().equals(other.tags, tags)&&const DeepCollectionEquality().equals(other.position, position)&&(identical(other.type, type) || other.type == type)&&(identical(other.imageColor, imageColor) || other.imageColor == imageColor)&&(identical(other.aspect, aspect) || other.aspect == aspect));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,categoryId,title,content,contentText,time,lastModified,show,deleted,mood,const DeepCollectionEquality().hash(weather),const DeepCollectionEquality().hash(imageName),const DeepCollectionEquality().hash(audioName),const DeepCollectionEquality().hash(videoName),const DeepCollectionEquality().hash(tags),const DeepCollectionEquality().hash(position),type,imageColor,aspect]);

@override
String toString() {
  return 'Diary(id: $id, categoryId: $categoryId, title: $title, content: $content, contentText: $contentText, time: $time, lastModified: $lastModified, show: $show, deleted: $deleted, mood: $mood, weather: $weather, imageName: $imageName, audioName: $audioName, videoName: $videoName, tags: $tags, position: $position, type: $type, imageColor: $imageColor, aspect: $aspect)';
}


}

/// @nodoc
abstract mixin class $DiaryCopyWith<$Res>  {
  factory $DiaryCopyWith(Diary value, $Res Function(Diary) _then) = _$DiaryCopyWithImpl;
@useResult
$Res call({
 String id,@Index() String? categoryId, String title, String content, String contentText,@Index()@UtcDateTimeConverter() DateTime time,@UtcDateTimeConverter() DateTime lastModified,@Index() bool show,@Index() bool deleted, double mood, List<String> weather, List<String> imageName, List<String> audioName, List<String> videoName, List<String> tags, List<String> position, String type, int? imageColor, double? aspect
});




}
/// @nodoc
class _$DiaryCopyWithImpl<$Res>
    implements $DiaryCopyWith<$Res> {
  _$DiaryCopyWithImpl(this._self, this._then);

  final Diary _self;
  final $Res Function(Diary) _then;

/// Create a copy of Diary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? categoryId = freezed,Object? title = null,Object? content = null,Object? contentText = null,Object? time = null,Object? lastModified = null,Object? show = null,Object? deleted = null,Object? mood = null,Object? weather = null,Object? imageName = null,Object? audioName = null,Object? videoName = null,Object? tags = null,Object? position = null,Object? type = null,Object? imageColor = freezed,Object? aspect = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,contentText: null == contentText ? _self.contentText : contentText // ignore: cast_nullable_to_non_nullable
as String,time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as DateTime,lastModified: null == lastModified ? _self.lastModified : lastModified // ignore: cast_nullable_to_non_nullable
as DateTime,show: null == show ? _self.show : show // ignore: cast_nullable_to_non_nullable
as bool,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,mood: null == mood ? _self.mood : mood // ignore: cast_nullable_to_non_nullable
as double,weather: null == weather ? _self.weather : weather // ignore: cast_nullable_to_non_nullable
as List<String>,imageName: null == imageName ? _self.imageName : imageName // ignore: cast_nullable_to_non_nullable
as List<String>,audioName: null == audioName ? _self.audioName : audioName // ignore: cast_nullable_to_non_nullable
as List<String>,videoName: null == videoName ? _self.videoName : videoName // ignore: cast_nullable_to_non_nullable
as List<String>,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as List<String>,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,imageColor: freezed == imageColor ? _self.imageColor : imageColor // ignore: cast_nullable_to_non_nullable
as int?,aspect: freezed == aspect ? _self.aspect : aspect // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [Diary].
extension DiaryPatterns on Diary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Diary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Diary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Diary value)  $default,){
final _that = this;
switch (_that) {
case _Diary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Diary value)?  $default,){
final _that = this;
switch (_that) {
case _Diary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @Index()  String? categoryId,  String title,  String content,  String contentText, @Index()@UtcDateTimeConverter()  DateTime time, @UtcDateTimeConverter()  DateTime lastModified, @Index()  bool show, @Index()  bool deleted,  double mood,  List<String> weather,  List<String> imageName,  List<String> audioName,  List<String> videoName,  List<String> tags,  List<String> position,  String type,  int? imageColor,  double? aspect)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Diary() when $default != null:
return $default(_that.id,_that.categoryId,_that.title,_that.content,_that.contentText,_that.time,_that.lastModified,_that.show,_that.deleted,_that.mood,_that.weather,_that.imageName,_that.audioName,_that.videoName,_that.tags,_that.position,_that.type,_that.imageColor,_that.aspect);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @Index()  String? categoryId,  String title,  String content,  String contentText, @Index()@UtcDateTimeConverter()  DateTime time, @UtcDateTimeConverter()  DateTime lastModified, @Index()  bool show, @Index()  bool deleted,  double mood,  List<String> weather,  List<String> imageName,  List<String> audioName,  List<String> videoName,  List<String> tags,  List<String> position,  String type,  int? imageColor,  double? aspect)  $default,) {final _that = this;
switch (_that) {
case _Diary():
return $default(_that.id,_that.categoryId,_that.title,_that.content,_that.contentText,_that.time,_that.lastModified,_that.show,_that.deleted,_that.mood,_that.weather,_that.imageName,_that.audioName,_that.videoName,_that.tags,_that.position,_that.type,_that.imageColor,_that.aspect);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @Index()  String? categoryId,  String title,  String content,  String contentText, @Index()@UtcDateTimeConverter()  DateTime time, @UtcDateTimeConverter()  DateTime lastModified, @Index()  bool show, @Index()  bool deleted,  double mood,  List<String> weather,  List<String> imageName,  List<String> audioName,  List<String> videoName,  List<String> tags,  List<String> position,  String type,  int? imageColor,  double? aspect)?  $default,) {final _that = this;
switch (_that) {
case _Diary() when $default != null:
return $default(_that.id,_that.categoryId,_that.title,_that.content,_that.contentText,_that.time,_that.lastModified,_that.show,_that.deleted,_that.mood,_that.weather,_that.imageName,_that.audioName,_that.videoName,_that.tags,_that.position,_that.type,_that.imageColor,_that.aspect);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Diary extends Diary {
  const _Diary({required this.id, @Index() this.categoryId, required this.title, required this.content, required this.contentText, @Index()@UtcDateTimeConverter() required this.time, @UtcDateTimeConverter() required this.lastModified, @Index() required this.show, @Index() required this.deleted, required this.mood, required final  List<String> weather, required final  List<String> imageName, required final  List<String> audioName, required final  List<String> videoName, required final  List<String> tags, required final  List<String> position, required this.type, this.imageColor, this.aspect}): _weather = weather,_imageName = imageName,_audioName = audioName,_videoName = videoName,_tags = tags,_position = position,super._();
  factory _Diary.fromJson(Map<String, dynamic> json) => _$DiaryFromJson(json);

@override final  String id;
@override@Index() final  String? categoryId;
@override final  String title;
@override final  String content;
@override final  String contentText;
@override@Index()@UtcDateTimeConverter() final  DateTime time;
@override@UtcDateTimeConverter() final  DateTime lastModified;
@override@Index() final  bool show;
@override@Index() final  bool deleted;
@override final  double mood;
 final  List<String> _weather;
@override List<String> get weather {
  if (_weather is EqualUnmodifiableListView) return _weather;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_weather);
}

 final  List<String> _imageName;
@override List<String> get imageName {
  if (_imageName is EqualUnmodifiableListView) return _imageName;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_imageName);
}

 final  List<String> _audioName;
@override List<String> get audioName {
  if (_audioName is EqualUnmodifiableListView) return _audioName;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_audioName);
}

 final  List<String> _videoName;
@override List<String> get videoName {
  if (_videoName is EqualUnmodifiableListView) return _videoName;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_videoName);
}

 final  List<String> _tags;
@override List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

 final  List<String> _position;
@override List<String> get position {
  if (_position is EqualUnmodifiableListView) return _position;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_position);
}

@override final  String type;
@override final  int? imageColor;
@override final  double? aspect;

/// Create a copy of Diary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DiaryCopyWith<_Diary> get copyWith => __$DiaryCopyWithImpl<_Diary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DiaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Diary&&(identical(other.id, id) || other.id == id)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.title, title) || other.title == title)&&(identical(other.content, content) || other.content == content)&&(identical(other.contentText, contentText) || other.contentText == contentText)&&(identical(other.time, time) || other.time == time)&&(identical(other.lastModified, lastModified) || other.lastModified == lastModified)&&(identical(other.show, show) || other.show == show)&&(identical(other.deleted, deleted) || other.deleted == deleted)&&(identical(other.mood, mood) || other.mood == mood)&&const DeepCollectionEquality().equals(other._weather, _weather)&&const DeepCollectionEquality().equals(other._imageName, _imageName)&&const DeepCollectionEquality().equals(other._audioName, _audioName)&&const DeepCollectionEquality().equals(other._videoName, _videoName)&&const DeepCollectionEquality().equals(other._tags, _tags)&&const DeepCollectionEquality().equals(other._position, _position)&&(identical(other.type, type) || other.type == type)&&(identical(other.imageColor, imageColor) || other.imageColor == imageColor)&&(identical(other.aspect, aspect) || other.aspect == aspect));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,categoryId,title,content,contentText,time,lastModified,show,deleted,mood,const DeepCollectionEquality().hash(_weather),const DeepCollectionEquality().hash(_imageName),const DeepCollectionEquality().hash(_audioName),const DeepCollectionEquality().hash(_videoName),const DeepCollectionEquality().hash(_tags),const DeepCollectionEquality().hash(_position),type,imageColor,aspect]);

@override
String toString() {
  return 'Diary(id: $id, categoryId: $categoryId, title: $title, content: $content, contentText: $contentText, time: $time, lastModified: $lastModified, show: $show, deleted: $deleted, mood: $mood, weather: $weather, imageName: $imageName, audioName: $audioName, videoName: $videoName, tags: $tags, position: $position, type: $type, imageColor: $imageColor, aspect: $aspect)';
}


}

/// @nodoc
abstract mixin class _$DiaryCopyWith<$Res> implements $DiaryCopyWith<$Res> {
  factory _$DiaryCopyWith(_Diary value, $Res Function(_Diary) _then) = __$DiaryCopyWithImpl;
@override @useResult
$Res call({
 String id,@Index() String? categoryId, String title, String content, String contentText,@Index()@UtcDateTimeConverter() DateTime time,@UtcDateTimeConverter() DateTime lastModified,@Index() bool show,@Index() bool deleted, double mood, List<String> weather, List<String> imageName, List<String> audioName, List<String> videoName, List<String> tags, List<String> position, String type, int? imageColor, double? aspect
});




}
/// @nodoc
class __$DiaryCopyWithImpl<$Res>
    implements _$DiaryCopyWith<$Res> {
  __$DiaryCopyWithImpl(this._self, this._then);

  final _Diary _self;
  final $Res Function(_Diary) _then;

/// Create a copy of Diary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? categoryId = freezed,Object? title = null,Object? content = null,Object? contentText = null,Object? time = null,Object? lastModified = null,Object? show = null,Object? deleted = null,Object? mood = null,Object? weather = null,Object? imageName = null,Object? audioName = null,Object? videoName = null,Object? tags = null,Object? position = null,Object? type = null,Object? imageColor = freezed,Object? aspect = freezed,}) {
  return _then(_Diary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,contentText: null == contentText ? _self.contentText : contentText // ignore: cast_nullable_to_non_nullable
as String,time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as DateTime,lastModified: null == lastModified ? _self.lastModified : lastModified // ignore: cast_nullable_to_non_nullable
as DateTime,show: null == show ? _self.show : show // ignore: cast_nullable_to_non_nullable
as bool,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,mood: null == mood ? _self.mood : mood // ignore: cast_nullable_to_non_nullable
as double,weather: null == weather ? _self._weather : weather // ignore: cast_nullable_to_non_nullable
as List<String>,imageName: null == imageName ? _self._imageName : imageName // ignore: cast_nullable_to_non_nullable
as List<String>,audioName: null == audioName ? _self._audioName : audioName // ignore: cast_nullable_to_non_nullable
as List<String>,videoName: null == videoName ? _self._videoName : videoName // ignore: cast_nullable_to_non_nullable
as List<String>,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,position: null == position ? _self._position : position // ignore: cast_nullable_to_non_nullable
as List<String>,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,imageColor: freezed == imageColor ? _self.imageColor : imageColor // ignore: cast_nullable_to_non_nullable
as int?,aspect: freezed == aspect ? _self.aspect : aspect // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
