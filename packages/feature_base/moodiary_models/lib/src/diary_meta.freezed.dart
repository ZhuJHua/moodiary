// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'diary_meta.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DiaryPosition {

 double get latitude; double get longitude;/// 展示用地名（行政区 + 城市名）。
 String get name;
/// Create a copy of DiaryPosition
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiaryPositionCopyWith<DiaryPosition> get copyWith => _$DiaryPositionCopyWithImpl<DiaryPosition>(this as DiaryPosition, _$identity);

  /// Serializes this DiaryPosition to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiaryPosition&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,latitude,longitude,name);

@override
String toString() {
  return 'DiaryPosition(latitude: $latitude, longitude: $longitude, name: $name)';
}


}

/// @nodoc
abstract mixin class $DiaryPositionCopyWith<$Res>  {
  factory $DiaryPositionCopyWith(DiaryPosition value, $Res Function(DiaryPosition) _then) = _$DiaryPositionCopyWithImpl;
@useResult
$Res call({
 double latitude, double longitude, String name
});




}
/// @nodoc
class _$DiaryPositionCopyWithImpl<$Res>
    implements $DiaryPositionCopyWith<$Res> {
  _$DiaryPositionCopyWithImpl(this._self, this._then);

  final DiaryPosition _self;
  final $Res Function(DiaryPosition) _then;

/// Create a copy of DiaryPosition
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? latitude = null,Object? longitude = null,Object? name = null,}) {
  return _then(DiaryPosition(
latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [DiaryPosition].
extension DiaryPositionPatterns on DiaryPosition {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DiaryPosition value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DiaryPosition() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DiaryPosition value)  $default,){
final _that = this;
switch (_that) {
case _DiaryPosition():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DiaryPosition value)?  $default,){
final _that = this;
switch (_that) {
case _DiaryPosition() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double latitude,  double longitude,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DiaryPosition() when $default != null:
return $default(_that.latitude,_that.longitude,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double latitude,  double longitude,  String name)  $default,) {final _that = this;
switch (_that) {
case _DiaryPosition():
return $default(_that.latitude,_that.longitude,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double latitude,  double longitude,  String name)?  $default,) {final _that = this;
switch (_that) {
case _DiaryPosition() when $default != null:
return $default(_that.latitude,_that.longitude,_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DiaryPosition implements DiaryPosition {
  const _DiaryPosition({required this.latitude, required this.longitude, required this.name});
  factory _DiaryPosition.fromJson(Map<String, dynamic> json) => _$DiaryPositionFromJson(json);

@override final  double latitude;
@override final  double longitude;
/// 展示用地名（行政区 + 城市名）。
@override final  String name;

/// Create a copy of DiaryPosition
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DiaryPositionCopyWith<_DiaryPosition> get copyWith => __$DiaryPositionCopyWithImpl<_DiaryPosition>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DiaryPositionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DiaryPosition&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,latitude,longitude,name);

@override
String toString() {
  return 'DiaryPosition(latitude: $latitude, longitude: $longitude, name: $name)';
}


}

/// @nodoc
abstract mixin class _$DiaryPositionCopyWith<$Res> implements $DiaryPositionCopyWith<$Res> {
  factory _$DiaryPositionCopyWith(_DiaryPosition value, $Res Function(_DiaryPosition) _then) = __$DiaryPositionCopyWithImpl;
@override @useResult
$Res call({
 double latitude, double longitude, String name
});




}
/// @nodoc
class __$DiaryPositionCopyWithImpl<$Res>
    implements _$DiaryPositionCopyWith<$Res> {
  __$DiaryPositionCopyWithImpl(this._self, this._then);

  final _DiaryPosition _self;
  final $Res Function(_DiaryPosition) _then;

/// Create a copy of DiaryPosition
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? latitude = null,Object? longitude = null,Object? name = null,}) {
  return _then(_DiaryPosition(
latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$DiaryWeather {

/// 和风天气图标码（如 `"100"`）。
 String get icon; String get temp;/// 文字描述（如「晴」/「多云」）。
 String get text;
/// Create a copy of DiaryWeather
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiaryWeatherCopyWith<DiaryWeather> get copyWith => _$DiaryWeatherCopyWithImpl<DiaryWeather>(this as DiaryWeather, _$identity);

  /// Serializes this DiaryWeather to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiaryWeather&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.temp, temp) || other.temp == temp)&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,icon,temp,text);

@override
String toString() {
  return 'DiaryWeather(icon: $icon, temp: $temp, text: $text)';
}


}

/// @nodoc
abstract mixin class $DiaryWeatherCopyWith<$Res>  {
  factory $DiaryWeatherCopyWith(DiaryWeather value, $Res Function(DiaryWeather) _then) = _$DiaryWeatherCopyWithImpl;
@useResult
$Res call({
 String icon, String temp, String text
});




}
/// @nodoc
class _$DiaryWeatherCopyWithImpl<$Res>
    implements $DiaryWeatherCopyWith<$Res> {
  _$DiaryWeatherCopyWithImpl(this._self, this._then);

  final DiaryWeather _self;
  final $Res Function(DiaryWeather) _then;

/// Create a copy of DiaryWeather
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? icon = null,Object? temp = null,Object? text = null,}) {
  return _then(DiaryWeather(
icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String,temp: null == temp ? _self.temp : temp // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [DiaryWeather].
extension DiaryWeatherPatterns on DiaryWeather {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DiaryWeather value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DiaryWeather() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DiaryWeather value)  $default,){
final _that = this;
switch (_that) {
case _DiaryWeather():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DiaryWeather value)?  $default,){
final _that = this;
switch (_that) {
case _DiaryWeather() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String icon,  String temp,  String text)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DiaryWeather() when $default != null:
return $default(_that.icon,_that.temp,_that.text);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String icon,  String temp,  String text)  $default,) {final _that = this;
switch (_that) {
case _DiaryWeather():
return $default(_that.icon,_that.temp,_that.text);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String icon,  String temp,  String text)?  $default,) {final _that = this;
switch (_that) {
case _DiaryWeather() when $default != null:
return $default(_that.icon,_that.temp,_that.text);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DiaryWeather implements DiaryWeather {
  const _DiaryWeather({required this.icon, required this.temp, required this.text});
  factory _DiaryWeather.fromJson(Map<String, dynamic> json) => _$DiaryWeatherFromJson(json);

/// 和风天气图标码（如 `"100"`）。
@override final  String icon;
@override final  String temp;
/// 文字描述（如「晴」/「多云」）。
@override final  String text;

/// Create a copy of DiaryWeather
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DiaryWeatherCopyWith<_DiaryWeather> get copyWith => __$DiaryWeatherCopyWithImpl<_DiaryWeather>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DiaryWeatherToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DiaryWeather&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.temp, temp) || other.temp == temp)&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,icon,temp,text);

@override
String toString() {
  return 'DiaryWeather(icon: $icon, temp: $temp, text: $text)';
}


}

/// @nodoc
abstract mixin class _$DiaryWeatherCopyWith<$Res> implements $DiaryWeatherCopyWith<$Res> {
  factory _$DiaryWeatherCopyWith(_DiaryWeather value, $Res Function(_DiaryWeather) _then) = __$DiaryWeatherCopyWithImpl;
@override @useResult
$Res call({
 String icon, String temp, String text
});




}
/// @nodoc
class __$DiaryWeatherCopyWithImpl<$Res>
    implements _$DiaryWeatherCopyWith<$Res> {
  __$DiaryWeatherCopyWithImpl(this._self, this._then);

  final _DiaryWeather _self;
  final $Res Function(_DiaryWeather) _then;

/// Create a copy of DiaryWeather
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? icon = null,Object? temp = null,Object? text = null,}) {
  return _then(_DiaryWeather(
icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String,temp: null == temp ? _self.temp : temp // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
