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
mixin _$DiaryWeather {

/// 和风天气图标码（如 `"100"`）。
 String get icon;/// 摄氏温度的数字字符串；null = 手选天气，没有温度。
 String? get temp;/// 文字描述（如「晴」/「多云」）。
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
  final _this = this as DiaryWeather;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiaryWeather&&(identical(other.icon, _this.icon) || other.icon == _this.icon)&&(identical(other.temp, _this.temp) || other.temp == _this.temp)&&(identical(other.text, _this.text) || other.text == _this.text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DiaryWeather;
  return Object.hash(runtimeType,_this.icon,_this.temp,_this.text);
}

@override
String toString() {
  final _this = this as DiaryWeather;
  return 'DiaryWeather(icon: ${_this.icon}, temp: ${_this.temp}, text: ${_this.text})';
}


}

/// @nodoc
abstract mixin class $DiaryWeatherCopyWith<$Res>  {
  factory $DiaryWeatherCopyWith(DiaryWeather value, $Res Function(DiaryWeather) _then) = _$DiaryWeatherCopyWithImpl;
@useResult
$Res call({
 String icon, String? temp, String text
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
@pragma('vm:prefer-inline') @override $Res call({Object? icon = null,Object? temp = freezed,Object? text = null,}) {
  return _then(DiaryWeather(
icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String,temp: freezed == temp ? _self.temp : temp // ignore: cast_nullable_to_non_nullable
as String?,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String icon,  String? temp,  String text)?  $default,{required TResult orElse(),}) {final _that = this;
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String icon,  String? temp,  String text)  $default,) {final _that = this;
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String icon,  String? temp,  String text)?  $default,) {final _that = this;
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
  const _DiaryWeather({required this.icon, this.temp, required this.text});
  factory _DiaryWeather.fromJson(Map<String, dynamic> json) => _$DiaryWeatherFromJson(json);

/// 和风天气图标码（如 `"100"`）。
@override final  String icon;
/// 摄氏温度的数字字符串；null = 手选天气，没有温度。
@override final  String? temp;
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
int get hashCode {
    return Object.hash(runtimeType,icon,temp,text);
}

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
 String icon, String? temp, String text
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
@override @pragma('vm:prefer-inline') $Res call({Object? icon = null,Object? temp = freezed,Object? text = null,}) {
  return _then(_DiaryWeather(
icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String,temp: freezed == temp ? _self.temp : temp // ignore: cast_nullable_to_non_nullable
as String?,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
