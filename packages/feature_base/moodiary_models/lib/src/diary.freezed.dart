// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'diary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Diary {

 String get id; String? get categoryId; String get title; String get content; String get contentText;@UtcDateTimeConverter() DateTime get time;@UtcDateTimeConverter() DateTime get lastModified; bool get show; double get mood; DiaryWeather? get weather; List<String> get imageName; List<String> get audioName; List<String> get videoName; List<String> get tags; DiaryPosition? get position; String get type; double? get aspect;
/// Create a copy of Diary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiaryCopyWith<Diary> get copyWith => _$DiaryCopyWithImpl<Diary>(this as Diary, _$identity);

  /// Serializes this Diary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Diary&&(identical(other.id, id) || other.id == id)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.title, title) || other.title == title)&&(identical(other.content, content) || other.content == content)&&(identical(other.contentText, contentText) || other.contentText == contentText)&&(identical(other.time, time) || other.time == time)&&(identical(other.lastModified, lastModified) || other.lastModified == lastModified)&&(identical(other.show, show) || other.show == show)&&(identical(other.mood, mood) || other.mood == mood)&&(identical(other.weather, weather) || other.weather == weather)&&const DeepCollectionEquality().equals(other.imageName, imageName)&&const DeepCollectionEquality().equals(other.audioName, audioName)&&const DeepCollectionEquality().equals(other.videoName, videoName)&&const DeepCollectionEquality().equals(other.tags, tags)&&(identical(other.position, position) || other.position == position)&&(identical(other.type, type) || other.type == type)&&(identical(other.aspect, aspect) || other.aspect == aspect));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,categoryId,title,content,contentText,time,lastModified,show,mood,weather,const DeepCollectionEquality().hash(imageName),const DeepCollectionEquality().hash(audioName),const DeepCollectionEquality().hash(videoName),const DeepCollectionEquality().hash(tags),position,type,aspect);

@override
String toString() {
  return 'Diary(id: $id, categoryId: $categoryId, title: $title, content: $content, contentText: $contentText, time: $time, lastModified: $lastModified, show: $show, mood: $mood, weather: $weather, imageName: $imageName, audioName: $audioName, videoName: $videoName, tags: $tags, position: $position, type: $type, aspect: $aspect)';
}


}

/// @nodoc
abstract mixin class $DiaryCopyWith<$Res>  {
  factory $DiaryCopyWith(Diary value, $Res Function(Diary) _then) = _$DiaryCopyWithImpl;
@useResult
$Res call({
 String id, String? categoryId, String title, String content, String contentText,@UtcDateTimeConverter() DateTime time,@UtcDateTimeConverter() DateTime lastModified, bool show, double mood, DiaryWeather? weather, List<String> imageName, List<String> audioName, List<String> videoName, List<String> tags, DiaryPosition? position, String type, double? aspect
});


$DiaryWeatherCopyWith<$Res>? get weather;$DiaryPositionCopyWith<$Res>? get position;

}
/// @nodoc
class _$DiaryCopyWithImpl<$Res>
    implements $DiaryCopyWith<$Res> {
  _$DiaryCopyWithImpl(this._self, this._then);

  final Diary _self;
  final $Res Function(Diary) _then;

/// Create a copy of Diary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? categoryId = freezed,Object? title = null,Object? content = null,Object? contentText = null,Object? time = null,Object? lastModified = null,Object? show = null,Object? mood = null,Object? weather = freezed,Object? imageName = null,Object? audioName = null,Object? videoName = null,Object? tags = null,Object? position = freezed,Object? type = null,Object? aspect = freezed,}) {
  return _then(Diary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,contentText: null == contentText ? _self.contentText : contentText // ignore: cast_nullable_to_non_nullable
as String,time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as DateTime,lastModified: null == lastModified ? _self.lastModified : lastModified // ignore: cast_nullable_to_non_nullable
as DateTime,show: null == show ? _self.show : show // ignore: cast_nullable_to_non_nullable
as bool,mood: null == mood ? _self.mood : mood // ignore: cast_nullable_to_non_nullable
as double,weather: freezed == weather ? _self.weather : weather // ignore: cast_nullable_to_non_nullable
as DiaryWeather?,imageName: null == imageName ? _self.imageName : imageName // ignore: cast_nullable_to_non_nullable
as List<String>,audioName: null == audioName ? _self.audioName : audioName // ignore: cast_nullable_to_non_nullable
as List<String>,videoName: null == videoName ? _self.videoName : videoName // ignore: cast_nullable_to_non_nullable
as List<String>,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as DiaryPosition?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,aspect: freezed == aspect ? _self.aspect : aspect // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}
/// Create a copy of Diary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DiaryWeatherCopyWith<$Res>? get weather {
    if (_self.weather == null) {
    return null;
  }

  return $DiaryWeatherCopyWith<$Res>(_self.weather!, (value) {
    return _then(_self.copyWith(weather: value));
  });
}/// Create a copy of Diary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DiaryPositionCopyWith<$Res>? get position {
    if (_self.position == null) {
    return null;
  }

  return $DiaryPositionCopyWith<$Res>(_self.position!, (value) {
    return _then(_self.copyWith(position: value));
  });
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? categoryId,  String title,  String content,  String contentText, @UtcDateTimeConverter()  DateTime time, @UtcDateTimeConverter()  DateTime lastModified,  bool show,  double mood,  DiaryWeather? weather,  List<String> imageName,  List<String> audioName,  List<String> videoName,  List<String> tags,  DiaryPosition? position,  String type,  double? aspect)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Diary() when $default != null:
return $default(_that.id,_that.categoryId,_that.title,_that.content,_that.contentText,_that.time,_that.lastModified,_that.show,_that.mood,_that.weather,_that.imageName,_that.audioName,_that.videoName,_that.tags,_that.position,_that.type,_that.aspect);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? categoryId,  String title,  String content,  String contentText, @UtcDateTimeConverter()  DateTime time, @UtcDateTimeConverter()  DateTime lastModified,  bool show,  double mood,  DiaryWeather? weather,  List<String> imageName,  List<String> audioName,  List<String> videoName,  List<String> tags,  DiaryPosition? position,  String type,  double? aspect)  $default,) {final _that = this;
switch (_that) {
case _Diary():
return $default(_that.id,_that.categoryId,_that.title,_that.content,_that.contentText,_that.time,_that.lastModified,_that.show,_that.mood,_that.weather,_that.imageName,_that.audioName,_that.videoName,_that.tags,_that.position,_that.type,_that.aspect);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? categoryId,  String title,  String content,  String contentText, @UtcDateTimeConverter()  DateTime time, @UtcDateTimeConverter()  DateTime lastModified,  bool show,  double mood,  DiaryWeather? weather,  List<String> imageName,  List<String> audioName,  List<String> videoName,  List<String> tags,  DiaryPosition? position,  String type,  double? aspect)?  $default,) {final _that = this;
switch (_that) {
case _Diary() when $default != null:
return $default(_that.id,_that.categoryId,_that.title,_that.content,_that.contentText,_that.time,_that.lastModified,_that.show,_that.mood,_that.weather,_that.imageName,_that.audioName,_that.videoName,_that.tags,_that.position,_that.type,_that.aspect);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Diary extends Diary {
  const _Diary({required this.id, this.categoryId, required this.title, required this.content, required this.contentText, @UtcDateTimeConverter() required this.time, @UtcDateTimeConverter() required this.lastModified, required this.show, required this.mood, this.weather, required  List<String> imageName, required  List<String> audioName, required  List<String> videoName, required  List<String> tags, this.position, required this.type, this.aspect}): _imageName = imageName,_audioName = audioName,_videoName = videoName,_tags = tags,super._();
  factory _Diary.fromJson(Map<String, dynamic> json) => _$DiaryFromJson(json);

@override final  String id;
@override final  String? categoryId;
@override final  String title;
@override final  String content;
@override final  String contentText;
@override@UtcDateTimeConverter() final  DateTime time;
@override@UtcDateTimeConverter() final  DateTime lastModified;
@override final  bool show;
@override final  double mood;
@override final  DiaryWeather? weather;
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

@override final  DiaryPosition? position;
@override final  String type;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Diary&&(identical(other.id, id) || other.id == id)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.title, title) || other.title == title)&&(identical(other.content, content) || other.content == content)&&(identical(other.contentText, contentText) || other.contentText == contentText)&&(identical(other.time, time) || other.time == time)&&(identical(other.lastModified, lastModified) || other.lastModified == lastModified)&&(identical(other.show, show) || other.show == show)&&(identical(other.mood, mood) || other.mood == mood)&&(identical(other.weather, weather) || other.weather == weather)&&const DeepCollectionEquality().equals(other._imageName, _imageName)&&const DeepCollectionEquality().equals(other._audioName, _audioName)&&const DeepCollectionEquality().equals(other._videoName, _videoName)&&const DeepCollectionEquality().equals(other._tags, _tags)&&(identical(other.position, position) || other.position == position)&&(identical(other.type, type) || other.type == type)&&(identical(other.aspect, aspect) || other.aspect == aspect));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,categoryId,title,content,contentText,time,lastModified,show,mood,weather,const DeepCollectionEquality().hash(_imageName),const DeepCollectionEquality().hash(_audioName),const DeepCollectionEquality().hash(_videoName),const DeepCollectionEquality().hash(_tags),position,type,aspect);

@override
String toString() {
  return 'Diary(id: $id, categoryId: $categoryId, title: $title, content: $content, contentText: $contentText, time: $time, lastModified: $lastModified, show: $show, mood: $mood, weather: $weather, imageName: $imageName, audioName: $audioName, videoName: $videoName, tags: $tags, position: $position, type: $type, aspect: $aspect)';
}


}

/// @nodoc
abstract mixin class _$DiaryCopyWith<$Res> implements $DiaryCopyWith<$Res> {
  factory _$DiaryCopyWith(_Diary value, $Res Function(_Diary) _then) = __$DiaryCopyWithImpl;
@override @useResult
$Res call({
 String id, String? categoryId, String title, String content, String contentText,@UtcDateTimeConverter() DateTime time,@UtcDateTimeConverter() DateTime lastModified, bool show, double mood, DiaryWeather? weather, List<String> imageName, List<String> audioName, List<String> videoName, List<String> tags, DiaryPosition? position, String type, double? aspect
});


@override $DiaryWeatherCopyWith<$Res>? get weather;@override $DiaryPositionCopyWith<$Res>? get position;

}
/// @nodoc
class __$DiaryCopyWithImpl<$Res>
    implements _$DiaryCopyWith<$Res> {
  __$DiaryCopyWithImpl(this._self, this._then);

  final _Diary _self;
  final $Res Function(_Diary) _then;

/// Create a copy of Diary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? categoryId = freezed,Object? title = null,Object? content = null,Object? contentText = null,Object? time = null,Object? lastModified = null,Object? show = null,Object? mood = null,Object? weather = freezed,Object? imageName = null,Object? audioName = null,Object? videoName = null,Object? tags = null,Object? position = freezed,Object? type = null,Object? aspect = freezed,}) {
  return _then(_Diary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,contentText: null == contentText ? _self.contentText : contentText // ignore: cast_nullable_to_non_nullable
as String,time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as DateTime,lastModified: null == lastModified ? _self.lastModified : lastModified // ignore: cast_nullable_to_non_nullable
as DateTime,show: null == show ? _self.show : show // ignore: cast_nullable_to_non_nullable
as bool,mood: null == mood ? _self.mood : mood // ignore: cast_nullable_to_non_nullable
as double,weather: freezed == weather ? _self.weather : weather // ignore: cast_nullable_to_non_nullable
as DiaryWeather?,imageName: null == imageName ? _self._imageName : imageName // ignore: cast_nullable_to_non_nullable
as List<String>,audioName: null == audioName ? _self._audioName : audioName // ignore: cast_nullable_to_non_nullable
as List<String>,videoName: null == videoName ? _self._videoName : videoName // ignore: cast_nullable_to_non_nullable
as List<String>,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as DiaryPosition?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,aspect: freezed == aspect ? _self.aspect : aspect // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

/// Create a copy of Diary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DiaryWeatherCopyWith<$Res>? get weather {
    if (_self.weather == null) {
    return null;
  }

  return $DiaryWeatherCopyWith<$Res>(_self.weather!, (value) {
    return _then(_self.copyWith(weather: value));
  });
}/// Create a copy of Diary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DiaryPositionCopyWith<$Res>? get position {
    if (_self.position == null) {
    return null;
  }

  return $DiaryPositionCopyWith<$Res>(_self.position!, (value) {
    return _then(_self.copyWith(position: value));
  });
}
}

// dart format on
